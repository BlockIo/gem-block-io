require 'block_io/version'
require 'httpclient'
require 'json'
require 'connection_pool'
require 'openssl'
require 'digest'
require 'securerandom'
require 'base64'
require 'ffi'

module BlockIo

  @api_key = nil
  @base_url = "https://dev.block.io/api/VERSION/API_CALL/?api_key="
  @pin = nil
  @encryptionKey = nil
  @conn_pool = nil
  @version = nil

  def self.set_options(args = {})
    # initialize BlockIo
    @api_key = args[:api_key]
    @pin = args[:pin]
    @encryptionKey = Helper.pinToAesKey(@pin) if !@pin.nil?

    @conn_pool = ConnectionPool.new(size: 5, timeout: 300) { HTTPClient.new }
    
    @version = args[:version] || 1 # default version is 1
    
    self.api_call(['get_balance',""])
  end

  def self.method_missing(m, *args, &block)      

    method_name = m.to_s

    if ['withdraw', 'withdraw_from_address', 'withdraw_from_addresses', 'withdraw_from_user', 'withdraw_from_users', 'withdraw_from_label', 'withdraw_from_labels'].include?(m.to_s) then

      self.withdraw(args.first, m.to_s)

    else
      params = get_params(args.first)
      self.api_call([method_name, params])
    end
    
  end 

  def self.withdraw(args = {}, method_name = 'withdraw')
    # validate arguments for withdrawal of funds TODO

    raise Exception.new("PIN not set. Use BlockIo.set_options(:api_key=>'API KEY',:pin=>'SECRET PIN',:version=>'API VERSION')") if @pin.nil?

    params = get_params(args)

    params += "&pin=#{@pin}" if @version == 1 # Block.io handles the Secret PIN in the legacy API (v1)

    response = self.api_call([method_name, params])
    
    if response['data'].has_key?('reference_id') then
      # Block.io's asking us to provide some client-side signatures, let's get to it

      # extract the passphrase
      encrypted_passphrase = response['data']['encrypted_passphrase']['passphrase']

      # let's get our private key
      key = Helper.extractKey(encrypted_passphrase, @encryptionKey)

      raise Exception.new('Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.') if key.public_key != response['data']['encrypted_passphrase']['signer_public_key']

      # let's sign all the inputs we can
      inputs = response['data']['inputs']

      inputs.each do |input|
        # iterate over all signers
        
        input['signers'].each do |signer|
          # if our public key matches this signer's public key, sign the data

          signer['signed_data'] = key.sign(input['data_to_sign']) if signer['signer_public_key'] == key.public_key

        end
        
      end

      # the response object is now signed, let's stringify it and finalize this withdrawal

      response = self.api_call(['sign_and_finalize_withdrawal',{:signature_data => response['data'].to_json}])

      # if we provided all the required signatures, this transaction went through
      # otherwise Block.io responded with data asking for more signatures
      # the latter will be the case for dTrust addresses
    end

    return response

  end


  private
  
  def self.api_call(endpoint)

    body = nil

    @conn_pool.with do |hc|
      # prevent initiation of HTTPClients every time we make this call, use a connection_pool

      hc.ssl_config.ssl_version = :TLSv1
      response = hc.post("#{@base_url.gsub('API_CALL',endpoint[0]).gsub('VERSION', 'v'+@version.to_s) + @api_key}", endpoint[1])
      
      begin
        body = JSON.parse(response.body)
        raise Exception.new(body['data']['error_message']) if !body['status'].eql?('success')
      rescue
        raise Exception.new('Unknown error occurred. Please report this.')
      end
    end
    
    body
  end

  private

  def self.get_params(args)
    # construct the parameter string
    params = ""
    
    args.each do |k,v|
      params += '&' if params.length > 0
      params += "#{k.to_s}=#{v.to_s}"
    end

    return params
  end

  public

  class Key

    def initialize(privkey = nil)
      @curve = ::OpenSSL::PKey::EC.new("secp256k1")
      @curve.generate_key if privkey.nil?
      @curve.private_key = OpenSSL::BN.from_hex(privkey) if @curve.private_key.nil?
      
      @curve.public_key = ::OpenSSL::PKey::EC::Point.from_hex(@curve.group,OpenSSL_EC.regenerate_key(@curve.private_key_hex)[1]) if @curve.public_key.nil?
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
      # signed the given hexadecimal string

      data_bin = [data].pack("H*") # convert hex to binary
      
      return @curve.dsa_sign_asn1(data_bin).unpack("H*")[0] # return the signed data in hex
    end
    
    def self.from_passphrase(passphrase)
      # create a private+public key pair from a given passphrase
      # think of this as your brain wallet. be very sure to use a sufficiently long passphrase
      # if you don't want a passphrase, just use Key.new and it will generate a random key for you
      
      raise Exception.new('Must provide passphrase at least 8 characters long.') if passphrase.nil? or passphrase.length < 8
      
      hashed_key = Helper.sha256([passphrase].pack("H*")) # must pass bytes to sha256

      return Key.new(hashed_key)
    end
    
  end
  
  module Helper
    
    def self.extractKey(encrypted_data, b64_enc_key)
      # passphrase is in plain text
      # encrypted_data is in base64, as it was stored on Block.io
      # returns the private key extracted from the given encrypted data
      
      decrypted = self.decrypt(encrypted_data, b64_enc_key)
      
      return Key.from_passphrase(decrypted)
    end
    
    def self.sha256(value)
      # returns the hex of the hash of the given value
      hash = Digest::SHA2.new(256)
      hash << value
      hash.hexdigest # return hex
    end
    
    def self.pinToAesKey(secret_pin, iterations = 2048)
      # converts the pincode string to PBKDF2
      # returns a base64 version of PBKDF2 pincode
      salt = ""
      aes_key_bin = OpenSSL::PKCS5.pbkdf2_hmac(secret_pin, salt, iterations/2, 16, OpenSSL::Digest::SHA256.new)
      aes_key_bin = OpenSSL::PKCS5.pbkdf2_hmac(aes_key_bin.unpack("H*")[0], salt, iterations/2, 32, OpenSSL::Digest::SHA256.new)
      
      return Base64.strict_encode64(aes_key_bin) # the base64 encryption key
    end
    
    # Decrypts a block of data (encrypted_data) given an encryption key
    def self.decrypt(encrypted_data, b64_enc_key, iv = nil, cipher_type = 'AES-256-ECB')
      
      response = nil

      begin
        aes = OpenSSL::Cipher::Cipher.new(cipher_type)
        aes.decrypt
        aes.key = Base64.strict_decode64(b64_enc_key)
        aes.iv = iv if iv != nil
        response = aes.update(Base64.strict_decode64(encrypted_data)) + aes.final
      rescue Exception => e
        # decryption failed, must be an invalid Secret PIN
        raise Exception.new('Invalid Secret PIN provided.')
      end

      return response
    end
    
    # Encrypts a block of data given an encryption key
    def self.encrypt(data, b64_enc_key, iv = nil, cipher_type = 'AES-256-ECB')
      aes = OpenSSL::Cipher::Cipher.new(cipher_type)
      aes.encrypt
      aes.key = Base64.strict_decode64(b64_enc_key)
      aes.iv = iv if iv != nil
      Base64.strict_encode64(aes.update(data) + aes.final)
    end
  end

end

# openssl stuff for signing data and converting private keys to (compressed) public keys
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

