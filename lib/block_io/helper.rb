module BlockIo

  class Helper

    def self.getSigHashForInput(tx, input_index, input_data, input_address_data)
      # returns the sighash for the given input in bytes
      
      address_type = input_address_data["address_type"]
      input_value = (BigDecimal(input_data['input_value']) * BigDecimal(100000000)).to_i # in sats
      sighash = nil
      
      if address_type == "P2SH" then
        # P2SH addresses
        
        script = Bitcoin::Script.to_p2sh_multisig_script(input_address_data["required_signatures"], input_address_data["public_keys"])
        sighash = tx.sighash_for_input(input_index, script.last)
        
      elsif address_type == "P2WSH-over-P2SH" or address_type == "WITNESS_V0" then
        # P2WSH-over-P2SH addresses
        # WITNESS_V0 addresses

        script = Bitcoin::Script.to_p2sh_multisig_script(input_address_data["required_signatures"], input_address_data["public_keys"])
        sighash = tx.sighash_for_input(input_index, script.last, amount: input_value, sig_version: :witness_v0)
        
      elsif address_type == "P2WPKH-over-P2SH" or address_type == "P2WPKH" then
        # P2WPKH-over-P2SH addresses
        # P2WPKH addresses
        
        pub_key = Bitcoin::Key.new(:pubkey => input_address_data['public_keys'].first, :key_type => 0x01) # compressed
        script = Bitcoin::Script.to_p2wpkh(pub_key.hash160)
        sighash = tx.sighash_for_input(input_index, script, amount: input_value, sig_version: :witness_v0)
        
      elsif address_type == "P2PKH" then
        # P2PKH addresses

        pub_key = Bitcoin::Key.new(:pubkey => input_address_data['public_keys'].first, :key_type => 0x01) # compressed
        script = Bitcoin::Script.to_p2pkh(pub_key.hash160)
        sighash = tx.sighash_for_input(input_index, script)

      else
        raise "Unrecognize address type: #{address_type}"
      end

      sighash
      
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
