require 'block_io/version'
require 'httpclient'
require 'json'
require 'connection_pool'
require 'openssl'
require 'digest'
require 'securerandom'
require 'base64'
require 'ffi'

module OpenSSL_EC
  extend FFI::Library
  ffi_lib 'ssl'

  NID_secp256k1 = 714

  attach_function :SSL_library_init, [], :int
  attach_function :ERR_load_crypto_strings, [], :void
  attach_function :SSL_load_error_strings, [], :void
  attach_function :RAND_poll, [], :int

  #attach_function :BN_bin2bn, [:string, :int, :pointer], :pointer
  attach_function :BN_bin2bn, [:pointer, :int, :pointer], :pointer
  attach_function :EC_KEY_new_by_curve_name, [:int], :pointer
  attach_function :EC_KEY_get0_group, [:pointer], :pointer
  attach_function :BN_new, [], :pointer
  attach_function :BN_CTX_new, [], :pointer
  attach_function :EC_GROUP_get_order, [:pointer, :pointer, :pointer], :int
  attach_function :EC_POINT_new, [:pointer], :pointer
  attach_function :EC_POINT_mul, [:pointer, :pointer, :pointer, :pointer, :pointer, :pointer], :int
  attach_function :EC_KEY_set_private_key, [:pointer, :pointer], :int
  attach_function :EC_KEY_set_public_key,  [:pointer, :pointer], :int
  attach_function :BN_free, [:pointer], :int
  attach_function :EC_POINT_free, [:pointer], :int
  attach_function :BN_CTX_free, [:pointer], :int
  attach_function :EC_KEY_free, [:pointer], :int
  attach_function :i2o_ECPublicKey, [:pointer, :pointer], :uint
  attach_function :i2d_ECPrivateKey, [:pointer, :pointer], :int

  def self.regenerate_key(private_key)
    # given a private key, generate the public key

    private_key = [private_key].pack("H*") if private_key.bytesize >= (32*2)

    private_key = FFI::MemoryPointer.new(:uint8, private_key.bytesize)
                    .put_bytes(0, private_key, 0, private_key.bytesize)
 
    init_ffi_ssl
    eckey = EC_KEY_new_by_curve_name(NID_secp256k1)
    priv_key = BN_bin2bn(private_key, private_key.size, BN_new())

    group, order, ctx = EC_KEY_get0_group(eckey), BN_new(), BN_CTX_new()
    EC_GROUP_get_order(group, order, ctx)

    pub_key = EC_POINT_new(group)
    EC_POINT_mul(group, pub_key, priv_key, nil, nil, ctx)
    EC_KEY_set_private_key(eckey, priv_key)
    EC_KEY_set_public_key(eckey, pub_key)

    BN_free(order)
    BN_CTX_free(ctx)
    EC_POINT_free(pub_key)
    BN_free(priv_key)

    length = i2d_ECPrivateKey(eckey, nil)
    ptr = FFI::MemoryPointer.new(:pointer)
    priv_hex = if i2d_ECPrivateKey(eckey, ptr) == length
      ptr.read_pointer.read_string(length)[9...9+32].unpack("H*")[0]
    end

    length = i2o_ECPublicKey(eckey, nil)
    ptr = FFI::MemoryPointer.new(:pointer)
    pub_hex = if i2o_ECPublicKey(eckey, ptr) == length
      ptr.read_pointer.read_string(length).unpack("H*")[0]
    end

    EC_KEY_free(eckey)

    [ priv_hex, pub_hex ]
  end

  def self.init_ffi_ssl
    return if @ssl_loaded
    SSL_library_init()
    ERR_load_crypto_strings()
    SSL_load_error_strings()
    RAND_poll()
    @ssl_loaded = true
  end
end

class Key

  def initialize(privkey = nil)
    @curve = ::OpenSSL::PKey::EC.new("secp256k1")
    @curve.generate_key if privkey.nil?
    @curve.private_key = OpenSSL::BN.from_hex(privkey) if @curve.private_key.nil?
    @curve.public_key = ::OpenSSL::PKey::EC::Point.from_hex(@curve.group,OpenSSL_EC.regenerate_key(@curve.private_key)[1]) if @curve.public_key.nil?
  end 

  def private_key
    # returns private key in hex form
    return @curve.private_key_hex
  end

  def public_key
    # returns the compressed form of the public key to save network fees (shorter scripts)
    @curve.public_key.group.point_conversion_form = :compressed
    hex = @curve.public_key.to_hex.rjust(66, '0')
    @curve.public_key.group.point_conversion_form = :uncompressed
    return hex
  end

  def sign(data)
    # signs the given binary data
    return @curve.dsa_sign_asn1(data)
  end

  def self.from_passphrase(passphrase)
    # create a private+public key pair from a given passphrase
    # think of this as your brain wallet. be very sure to use a sufficiently long passphrase
    # if you don't want a passphrase, just use Key.new and it will generate a random key for you

    raise Exception.new('Must provide passphrase at least 8 characters long.') if passphrase.nil? or passphrase.length < 8

    # get the PBKDF2 key
    salt = ""
    iterations = 1000

    hashed_key = OpenSSL::PKCS5.pbkdf2_hmac(passphrase, salt, iterations, 32, OpenSSL::Digest::SHA256.new).unpack("H*")[0] # in hex

    return Key.new(hashed_key)
  end

end

module BlockHelper

  def self.extractPrivateKey(encrypted_data, passphrase)
    # passphrase is in plain text
    # encrypted_data is in base64, as it was stored on Block.io
    # returns the private key extracted from the given encrypted data
    
    decrypted = BlockHelper.decrypt(encrypted_data, passphrase)
    private_key = BlockHelper.sha256(decrypted)
    return private_key
  end

  def self.getPublicKey(private_key)
    # private_key must be in hex
    # return compressed public key
    return Key.new(private_key).public_key
  end

  def self.sha256(value)
    # returns the hex of the hash of the given value
    hash = Digest::SHA2.new(256)
    hash << value
    hash.hexdigest # return hex
  end

  def self.signData(data, private_key)
    # data in hex form, private_key in hex form
    # returns the signed data in hex form

    data_bin = [data].pack("H*") # convert hex to binary

    key = Key.new(private_key)
    return key.sign(data_bin).unpack("H*")[0]
  end

  def self.pinToAesKey(passphrase, iterations = 1)
    # converts the pincode string to PBKDF2
    # returns a base64 version of PBKDF2 pincode
    salt = ""
    aes_key_bin = OpenSSL::PKCS5.pbkdf2_hmac(passphrase, salt, iterations, 32, OpenSSL::Digest::SHA256.new)
    return Base64.strict_encode64(aes_key_bin)
  end

  # Decrypts a block of data (encrypted_data) given an encryption key
  def self.decrypt(encrypted_data, passphrase, iv = nil, cipher_type = 'AES-256-ECB')
    aes = OpenSSL::Cipher::Cipher.new(cipher_type)
    aes.decrypt
    aes.key = Base64.strict_decode64(BlockHelper.pinToAesKey(passphrase))
    aes.iv = iv if iv != nil
    aes.update(Base64.strict_decode64(encrypted_data)) + aes.final
  end
  
  # Encrypts a block of data given an encryption key
  def self.encrypt(data, passphrase, iv = nil, cipher_type = 'AES-256-ECB')
    aes = OpenSSL::Cipher::Cipher.new(cipher_type)
    aes.encrypt
    aes.key = Base64.strict_decode64(BlockHelper.pinToAesKey(passphrase))
    aes.iv = iv if iv != nil
    Base64.strict_encode64(aes.update(data) + aes.final)
  end
end

module ::OpenSSL
  class BN
    def self.from_hex(hex); new(hex, 16); end
    def to_hex; to_i.to_s(16); end
    def to_mpi; to_s(0).unpack("C*"); end
  end
  class PKey::EC
    def private_key_hex; private_key.to_hex.rjust(64, '0'); end
    def public_key_hex;  public_key.to_hex.rjust(130, '0'); end
    def pubkey_compressed?; public_key.group.point_conversion_form == :compressed; end
  end
  class PKey::EC::Point
    def self.from_hex(group, hex)
      new(group, BN.from_hex(hex))
    end
    def to_hex; to_bn.to_hex; end
    def self.bn2mpi(hex) BN.from_hex(hex).to_mpi; end
  end
end

module BlockIo

  @api_key = nil
  @base_url = "https://block.io/api/v1/API_CALL/?api_key="
  @pin = nil
  @conn_pool = nil

  def self.set_options(args = {})
    # initialize BlockIo
    @api_key = args[:api_key]
    @pin = args[:pin]
    @conn_pool = ConnectionPool.new(size: 5, timeout: 300) { HTTPClient.new }

    self.api_call(['get_balance',""])
  end

  def self.get_offline_vault_balance
    # returns the offline vault's balance
    endpoint = ["get_offline_vault_balance",""]
    self.api_call(endpoint)
  end

  def self.get_offline_vault_address
    # returns the offline vault's address and balance info
    self.get_offline_vault_balance
  end

  def self.get_balance
    # returns the balances for your account tied to the API key
    endpoint = ["get_balance", ""] 
    self.api_call(endpoint)
  end

  def self.get_user_balance(args)
    # returns the specified user's balance
    
    user_id = args[:user_id]

    raise Exception.new("Must provide user_id") if user_id.nil?

    endpoint = ['get_user_balance',"&user_id=#{user_id}"]

    self.api_call(endpoint)
  end

  def self.get_address_balance(args)
    # returns the specified address or address_label's balance
    
    address = args[:address]
    address_label = args[:address_label]

    raise Exception.new("Must provide ONE of address or address_label") if (!address.nil? and !address_label.nil?) or (address.nil? and address_label.nil?)

    endpoint = ['get_address_balance',"&address=#{address}"] unless address.nil?
    endpoint = ['get_address_balance',"&address_label=#{address_label}"] unless address_label.nil?

    self.api_call(endpoint)
  end

  def self.get_current_price(args = {})
    # returns prices from different exchanges as an array of hashes
    price_base = args[:price_base]

    endpoint = ['get_current_price', '']
    endpoint = ['get_current_price',"&price_base=#{price_base}"] unless price_base.nil? or price_base.to_s.length == 0

    self.api_call(endpoint)
  end

  def self.withdraw_from_user(args = {})
    # withdraws coins from the given user(s)
    self.withdraw(args)
  end

  def self.withdraw(args = {})
    # validate arguments for withdrawal of funds TODO

    raise Exception.new("PIN not set. Use BlockIo.set_options(:api_key=>'API KEY',:pin=>'SECRET PIN')") if @pin.nil?

    # validate argument sets
    amount = args[:amount]
    to_user_id = args[:to_user_id]
    payment_address = args[:payment_address]
    from_user_ids = args[:from_user_ids] || args[:from_user_id]

    raise Exception.new("Must provide ONE of payment_address, or to_user_id") if (!to_user_id.nil? and !payment_address.nil?) or (to_user_id.nil? and payment_address.nil?)
    raise Exception.new("Must provide amount to withdraw") if amount.nil?

    endpoint = ['withdraw',"&amount=#{amount}&payment_address=#{payment_address}&pin=#{@pin}"] unless payment_address.nil?
    endpoint = ['withdraw',"&amount=#{amount}&to_user_id=#{to_user_id}&pin=#{@pin}"] unless to_user_id.nil?
    endpoint = ['withdraw',"&amount=#{amount}&from_user_ids=#{from_user_ids}&pin=#{@pin}&payment_address=#{payment_address}"] unless from_user_ids.nil? or payment_address.nil?
    endpoint = ['withdraw',"&amount=#{amount}&from_user_ids=#{from_user_ids}&to_user_id=#{to_user_id}&pin=#{@pin}"] unless to_user_id.nil? or from_user_ids.nil?

    self.api_call(endpoint)
  end

  def self.get_new_address(args = {})
    # validate arguments for getting a new address
    address_label = args[:address_label]

    endpoint = ['get_new_address','']
    endpoint = ["get_new_address","&address_label=#{address_label}"] unless address_label.nil?

    self.api_call(endpoint)
  end

  def self.create_user(args = {})
    # validate arguments for getting a new address
    address_label = args[:address_label]

    endpoint = ['create_user','']
    endpoint = ['create_user',"&address_label=#{address_label}"] unless address_label.nil?

    self.api_call(endpoint)
  end  

  def self.get_my_addresses(args = {})
    # returns all the addresses in your account tied to the API key
    endpoint = ["get_my_addresses",""]

    self.api_call(endpoint)
  end

  def self.get_users(args = {})
    # returns all the addresses in your account tied to the API key
    endpoint = ['get_users',""]

    self.api_call(endpoint)
  end

  def self.get_address_received(args = {})
    # get coins received, confirmed and unconfirmed, by the given address, address_label, or user_id
    address_label = args[:address_label]
    user_id = args[:user_id]
    address = args[:address]

    raise Exception.new("Must provide ONE of address_label, user_id, or address") unless args.keys.length == 1 and (!address_label.nil? or !user_id.nil? or !address.nil?)

    endpoint = ['get_address_received','']
    endpoint = ["get_address_received","&user_id=#{user_id}"] unless user_id.nil?
    endpoint = ['get_address_received',"&address_label=#{address_label}"] unless address_label.nil?
    endpoint = ['get_address_received',"&address=#{address}"] unless address.nil?

    self.api_call(endpoint)
  end

  def self.get_user_received(args = {})
    # returns the user's received coins, confirmed and unconfirmed

    user_id = args[:user_id]

    raise Exception.new("Must provide user_id") if user_id.nil?

    self.get_address_received(:user_id => user_id)
  end

  def self.get_address_by_label(args = {})
    # get address by label

    address_label = args[:address_label]

    raise Exception.new("Must provide address_label") if address_label.nil?

    endpoint = ["get_address_by_label","&address_label=#{address_label}"]

    self.api_call(endpoint)
  end

  def self.get_user_address(args = {})
    # gets the user's address

    user_id = args[:user_id]

    raise Exception.new("Must provide user_id") if user_id.nil?

    endpoint = ['get_user_address',"&user_id=#{user_id}"]

    self.api_call(endpoint)
  end

  private

  def self.api_call(endpoint)

    body = nil

    @conn_pool.with do |hc|
      # prevent initiation of HTTPClients every time we make this call, use a connection_pool

      hc.ssl_config.ssl_version = :TLSv1
      response = hc.get("#{@base_url.gsub('API_CALL',endpoint[0]) + @api_key + endpoint[1]}")
      body = JSON.parse(response.body)
      
    end
    
    body
  end

end
