module BlockIo

  class Helper

    def self.signData(inputs, keys)
      # sign the given data with the given keys

      raise Exception.new("Keys object must be a hash or array containing the appropriate keys.") unless keys.size >= 1

      signatures_added = false
      
      # create a dictionary of keys we have
      # saves the next loop from being O(n^3)
      hkeys = (keys.is_a?(Hash) ? keys : keys.inject({}){|h,v| h[v.public_key] = v; h})
      odata = []

      # saves the next loop from being O(n^2)
      inputs.each{|input| odata << input["data_to_sign"]; odata << input["signatures_needed"]; odata.push(*input["signers"])}

      data_to_sign = nil
      signatures_needed = nil
      
      while !(cdata = odata.shift).nil? do
        # O(n)
        
        if cdata.is_a?(String) then
          # this is data to sign

          # make a copy of this
          data_to_sign = '' << cdata

          # number of signatures needed
          signatures_needed = 0 + odata.shift

        else
          # add signatures if necessary
          # dTrust required signatures may be lower than number of keys provided
          
          if hkeys.key?(cdata["signer_public_key"]) and signatures_needed > 0 and cdata["signed_data"].nil? then
            cdata["signed_data"] = hkeys[cdata["signer_public_key"]].sign(data_to_sign) 
            signatures_needed -= 1
            signatures_added ||= true
          end
          
        end

      end

      signatures_added
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

      part1 = OpenSSL::PKCS5.pbkdf2_hmac(
        secret_pin,
        "",
        1024,
        128/8,
        OpenSSL::Digest::SHA256.new
      ).unpack("H*")[0]
      
      part2 = OpenSSL::PKCS5.pbkdf2_hmac(
        part1,
        "",
        1024,
        256/8,
        OpenSSL::Digest::SHA256.new
      ) # binary

      [part2].pack("m0") # the base64 encryption key

    end
    
    # Decrypts a block of data (encrypted_data) given an encryption key
    def self.decrypt(encrypted_data, b64_enc_key, iv = nil, cipher_type = "AES-256-ECB")
      
      response = nil

      begin
        aes = OpenSSL::Cipher.new(cipher_type)
        aes.decrypt
        aes.key = b64_enc_key.unpack("m0")[0]
        aes.iv = iv unless iv.nil?
        response = aes.update(encrypted_data.unpack("m0")[0]) << aes.final
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
      aes.iv = iv unless iv.nil?
      [aes.update(data) << aes.final].pack("m0")
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
