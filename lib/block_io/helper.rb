module BlockIo

  class Helper

    def self.allSignaturesPresent?(tx, inputs, signatures, input_address_data)
      # returns true if transaction has all signatures present
      
      all_signatures_present = false

      inputs.each do |input|
        # check if each input has its required signatures
        
        spending_address = input['spending_address']
        current_input_address_data = input_address_data.detect{|x| x['address'] == spending_address}
        required_signatures = current_input_address_data['required_signatures']
        public_keys = current_input_address_data['public_keys']

        signatures_present = signatures.map{|x| x if x['input_index'] == input['input_index']}.compact.inject({}){|h,v| h[v['public_key']] = v['signature']; h}

        # break the loop if all signatures are not present for this input
        all_signatures_present = (signatures_present.keys.size >= required_signatures)
        break unless all_signatures_present
        
      end

      all_signatures_present

    end
    
    def self.finalizeTransaction(tx, inputs, signatures, input_address_data)
      # append signatures to the transaction and return its hexadecimal representation

      inputs.each do |input|
        # for each input

        signatures_present = signatures.map{|x| x if x['input_index'] == input['input_index']}.compact.inject({}){|h,v| h[v['public_key']] = v['signature']; h}
        address_data = input_address_data.detect{|x| x['address'] == input['spending_address']} # contains public keys (ordered) and the address type
        input_index = input['input_index']
        
        if ['P2PKH'].include?(address_data['address_type']) then
          # just a P2PKH input
          
          current_public_key = address_data['public_keys'][0]
          current_signature = signatures_present[current_public_key]
          tx.in[input_index].script_sig << ([current_signature].pack("H*") + [Bitcoin::SIGHASH_TYPE[:all]].pack('C'))
          tx.in[input_index].script_sig << [current_public_key].pack("H*")
          
        elsif ['P2SH'].include?(address_data['address_type']) then
          # just a P2SH input
          
          script = Bitcoin::Script.to_p2sh_multisig_script(address_data['required_signatures'], address_data['public_keys'])

          i = 0
          while i < address_data['required_signatures'] do
            # append signatures using SIGHASH[ALL] in correct order of public keys
            
            current_signature = signatures_present[address_data['public_keys'][i]]
            tx.in[input_index].script_sig << ([current_signature].pack("H*") + [Bitcoin::SIGHASH_TYPE[:all]].pack('C'))

            i += 1 # next public key
          end

          tx.in[input_index].script_sig << script.last.to_payload
          
        elsif ['P2WPKH', 'P2WPKH-over-P2SH'].include?(address_data['address_type']) then
          # a P2WPKH input, or a P2WPKH-over-P2SH input

          current_public_key = address_data['public_keys'][0]
          current_signature = signatures_present[current_public_key]

          # P2WPKH does not have a blank push to init the stack, only scripthash witnesses do
          tx.in[input_index].script_witness.stack << ([current_signature].pack("H*") + [Bitcoin::SIGHASH_TYPE[:all]].pack('C'))
          tx.in[input_index].script_witness.stack << [current_public_key].pack("H*")

          # P2WPKH-over-P2SH required script_sig still
          tx.in[input_index].script_sig << (
            Bitcoin::Script.to_p2wpkh(
              Bitcoin::Key.new(:pubkey => current_public_key, :key_type => 0x01).hash160 # hash160 of the compressed pubkey
            ).to_payload
          ) if address_data['address_type'].end_with?("P2SH")
                    
        elsif ['WITNESS_V0', 'P2WSH-over-P2SH'].include?(address_data['address_type']) then
        # P2WSH or P2WSH-over-P2SH input

          script = Bitcoin::Script.to_p2sh_multisig_script(address_data['required_signatures'], address_data['public_keys'])

          tx.in[input_index].script_witness.stack << '' # blank push for scripthash witnesses
          
          i = 0
          while i < address_data['required_signatures'] do
            # append signatures using SIGHASH[ALL] in correct order of public keys
            
            current_signature = signatures_present[address_data['public_keys'][i]]
            tx.in[input_index].script_witness.stack << ([current_signature].pack("H*") + [Bitcoin::SIGHASH_TYPE[:all]].pack('C'))
            
            i += 1 # next public key
            
          end

          tx.in[input_index].script_witness.stack << script.last.to_payload

          # P2WSH-over-P2SH needs script_sig populated still
          tx.in[input_index].script_sig << Bitcoin::Script.to_p2wsh(script.last).to_payload if address_data['address_type'].end_with?("P2SH")
          
        else
          raise "Unrecognized input address: #{address_data['address_type']}"
        end
        
      end

      tx.to_hex
      
    end
    
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
