require 'block_io/version'
require 'httpclient'
require 'json'
require 'connection_pool'
require 'ecdsa'
require 'openssl'
require 'digest'
require 'securerandom'
require 'base64'

module BlockIo

  @api_key = nil
  @base_url = "https://block.io/api/VERSION/API_CALL/?api_key="
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
    
    @version = args[:version] || 2 # default version is 2
    
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
      # the privkey must be in hex if at all provided

      @group = ECDSA::Group::Secp256k1
      @private_key = privkey.to_i(16) || 1 + SecureRandom.random_number(group.order - 1)
      @public_key = @group.generator.multiply_by_scalar(@private_key)

    end 
    
    def private_key
      # returns private key in hex form
      return @private_key.to_s(16)
    end
    
    def public_key
      # returns the compressed form of the public key to save network fees (shorter scripts)

      return ECDSA::Format::PointOctetString.encode(@public_key, compression: true).unpack("H*")[0]
    end
    
    def sign(data)
      # signed the given hexadecimal string

      nonce = 1 + SecureRandom.random_number(@group.order - 1) # nonce, can be made deterministic TODO
      
      signature = ECDSA.sign(@group, @private_key, [data].pack("H*"), nonce)

      # DER encode this, and return it in hex form

      return ECDSA::Format::SignatureDerString.encode(signature).unpack("H*")[0]

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
