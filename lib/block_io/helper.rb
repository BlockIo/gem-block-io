module BlockIo

  class Helper

    def self.api_call(args)

      response = HTTP.headers(:accept => "application/json", :user_agent => "gem:block_io:#{VERSION}").
                   post("#{args[:base_url]}/#{args[:method_name]}", :json => args[:params].merge({:api_key => args[:api_key]}))
      
      begin
        body = Oj.safe_load(response.to_s)
        raise Exception.new(body["data"]["error_message"]) unless body["status"].eql?("success")
      rescue
        raise Exception.new("Unknown error occurred. Please report this to support@block.io. Status #{response.code}.")
      end
      
      body
      
    end
    
    def self.signData(inputs, keys)
      # sign the given data with the given keys
      # TODO loop is O(n^3), make it better

      raise Exception.new("Keys object must be an array of keys, without at least one key inside it.") unless keys.is_a?(Array) and keys.size >= 1

      i = 0
      while i < inputs.size do
        # iterate over all signers
        input = inputs[i]

        j = 0
        while j < input['signers'].size do
          # if our public key matches this signer's public key, sign the data
          signer = inputs[i]['signers'][j]
          
          k = 0
          while k < keys.size do
            # sign for each key provided, if we can
            key = keys[k]
            signer['signed_data'] = key.sign(input['data_to_sign']) if signer['signer_public_key'] == key.public_key
            k = k + 1
          end

          j = j + 1
        end

        i = i + 1
      end

      inputs
    end

    def self.extractKey(encrypted_data, b64_enc_key)
      # passphrase is in plain text
      # encrypted_data is in base64, as it was stored on Block.io
      # returns the private key extracted from the given encrypted data
      
      decrypted = self.decrypt(encrypted_data, b64_enc_key)
      
      Key.from_passphrase(decrypted)

    end
    
    def self.sha256(value)
      # returns the hex of the hash of the given value
      OpenSSL::Digest::SHA256.digest(value).unpack("H*")[0]
    end
    
    def self.pinToAesKey(secret_pin, iterations = 2048)
      # converts the pincode string to PBKDF2
      # returns a base64 version of PBKDF2 pincode
      salt = ""

      k1 = OpenSSL::PKCS5.pbkdf2_hmac(
        secret_pin,
        "",
        1024,
        128/8,
        OpenSSL::Digest::SHA256.new
      ).unpack("H*")[0]
      
      k2 = OpenSSL::PKCS5.pbkdf2_hmac(
        k1,
        "",
        1024,
        256/8,
        OpenSSL::Digest::SHA256.new
      ) # binary

      [k2].pack("m0") # the base64 encryption key

    end
    
    # Decrypts a block of data (encrypted_data) given an encryption key
    def self.decrypt(encrypted_data, b64_enc_key, iv = nil, cipher_type = "AES-256-ECB")
      
      response = nil

      begin
        aes = OpenSSL::Cipher.new(cipher_type)
        aes.decrypt
        aes.key = b64_enc_key.unpack("m0")[0]
        aes.iv = iv if iv != nil
        response = aes.update(encrypted_data.unpack("m0")[0]) + aes.final
      rescue Exception => e
        # decryption failed, must be an invalid Secret PIN
        raise Exception.new("Invalid Secret PIN provided.")
      end

      response
    end
    
    # Encrypts a block of data given an encryption key
    def self.encrypt(data, b64_enc_key, iv = nil, cipher_type = "AES-256-ECB")
      aes = OpenSSL::Cipher.new(cipher_type)
      aes.encrypt
      aes.key = b64_enc_key.unpack("m0")[0]
      aes.iv = iv if iv != nil
      [aes.update(data) + aes.final].pack("m0")
    end

    # courtesy bitcoin-ruby
    
    def self.int_to_base58(int_val, leading_zero_bytes=0)
      alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      base58_val, base = "", alpha.size
      while int_val > 0
        int_val, remainder = int_val.divmod(base)
        base58_val = alpha[remainder] << base58_val
      end
      base58_val
    end
    
    def self.base58_to_int(base58_val)
      alpha = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      int_val, base = 0, alpha.size
      base58_val.reverse.each_char.with_index do |char,index|
        raise ArgumentError, "Value not a valid Base58 String." unless char_index = alpha.index(char)
        int_val += char_index*(base**index)
      end
      int_val
    end
    
    def self.encode_base58(hex)
      leading_zero_bytes  = (hex.match(/^([0]+)/) ? $1 : "").size / 2
      ("1"*leading_zero_bytes) << Helper.int_to_base58( hex.to_i(16) )
    end
    
    def self.decode_base58(base58_val)
      s = Helper.base58_to_int(base58_val).to_s(16)
      s = (s.bytesize.odd? ? ("0" << s) : s)
      s = "" if s == "00"
      leading_zero_bytes = (base58_val.match(/^([1]+)/) ? $1 : "").size
      s = ("00"*leading_zero_bytes) << s  if leading_zero_bytes > 0
      s
    end
  end

end
