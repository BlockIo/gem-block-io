module BlockIo

  class Helper

    LEGACY_DECRYPTION_ALGORITHM = {
      :pbkdf2_salt => '',
      :pbkdf2_iterations => 2048,
      :pbkdf2_hash_function => 'SHA256',
      :pbkdf2_phase1_key_length => 16,
      :pbkdf2_phase2_key_length => 32,
      :aes_iv => nil,
      :aes_cipher => 'AES-256-ECB',
      :aes_auth_tag => nil,
      :aes_auth_data => nil
    }
    
    def self.allSignaturesPresent?(tx, inputs, signatures, input_address_data)
      # returns true if transaction has all signatures present
      
      all_signatures_present = false

      i = 0
      loop do
        # check if each input has its required signatures
        input = inputs[i]
        break if input.nil?
        i += 1
        
        spending_address = input['spending_address']
        current_input_address_data = input_address_data.detect{|x| x['address'].eql?(spending_address)}
        required_signatures = current_input_address_data['required_signatures']
        public_keys = current_input_address_data['public_keys']

        signatures_present = signatures.map{|x| x if x['input_index'].eql?(input['input_index'])}.compact.inject({}){|h,v| h[v['public_key']] = v['signature']; h}

        # break the loop if all signatures are not present for this input
        all_signatures_present = (signatures_present.size >= required_signatures)
        break unless all_signatures_present        
      end

      all_signatures_present

    end

    def self.isSegwitAddressType?(address_type)

      case address_type
      when /^P2WPKH(-over-P2SH)?$/
        true
      when /^P2WSH(-over-P2SH)?$/
        true
      when /^WITNESS_V(\d)$/
        true
      else
        false
      end
        
    end
    
    def self.finalizeTransaction(tx, inputs, signatures, input_address_data)
      # append signatures to the transaction and return its hexadecimal representation

      i = 0
      loop do
        # for each input
        input = inputs[i]
        break if input.nil?
        i += 1

        signatures_present = signatures.map{|x| x if x['input_index'].eql?(input['input_index'])}.compact.inject({}){|h,v| h[v['public_key']] = v['signature']; h}
        address_data = input_address_data.detect{|x| x['address'].eql?(input['spending_address'])} # contains public keys (ordered) and the address type
        input_index = input['input_index']
        is_segwit = isSegwitAddressType?(address_data['address_type'])
        script_stack = (is_segwit ? tx.in[input_index].script_witness.stack : tx.in[input_index].script_sig)
        
        if ['P2PKH', 'P2WPKH', 'P2WPKH-over-P2SH'].include?(address_data['address_type']) then
          # P2PKH will use script_sig as script_stack
          # P2WPKH input, or P2WPKH-over-P2SH input will use script_witness.stack as script_stack

          current_public_key = address_data['public_keys'][0]
          current_signature = signatures_present[current_public_key]

          # no blank push necessary for P2PKH, P2WPKH, P2WPKH-over-P2SH
          script_stack << ([current_signature].pack('H*') + [Bitcoin::SIGHASH_TYPE[:all]].pack('C'))
          script_stack << [current_public_key].pack('H*')

          # P2WPKH-over-P2SH required script_sig still
          tx.in[input_index].script_sig << (
            Bitcoin::Script.to_p2wpkh(
              Bitcoin::Key.new(:pubkey => current_public_key, :key_type => Bitcoin::Key::TYPES[:compressed]).hash160 # hash160 of the compressed pubkey
            ).to_payload
          ) if address_data['address_type'].eql?('P2WPKH-over-P2SH')
          
        elsif ['P2SH', 'WITNESS_V0', 'P2WSH-over-P2SH'].include?(address_data['address_type']) then
          # P2SH will use script_sig as script_stack
          # P2WSH or P2WSH-over-P2SH input will use script_witness.stack as script_stack

          script = Bitcoin::Script.to_p2sh_multisig_script(address_data['required_signatures'], address_data['public_keys'])

          script_stack << '' # blank push for scripthash always

          signatures_added = 0

          j = 0
          loop do
            public_key = address_data['public_keys'][j]
            break if public_key.nil?
            j += 1
            next unless signatures_present.key?(public_key)

            # append signatures, no sighash needed, in correct order of public keys
            current_signature = signatures_present[public_key]
            script_stack << ([current_signature].pack('H*') + [Bitcoin::SIGHASH_TYPE[:all]].pack('C'))

            signatures_added += 1

            # required signatures added? break loop and move on
            break if signatures_added.eql?(address_data['required_signatures'])
          end

          script_stack << script.last.to_payload

          # P2WSH-over-P2SH needs script_sig populated still
          tx.in[input_index].script_sig << Bitcoin::Script.to_p2wsh(script.last).to_payload if address_data['address_type'].eql?('P2WSH-over-P2SH')
          
        else
          raise "Unrecognized input address: #{address_data['address_type']}"
        end
        
      end

      tx.to_hex
      
    end
    
    def self.getSigHashForInput(tx, input_index, input_data, input_address_data)
      # returns the sighash for the given input in bytes
      
      address_type = input_address_data['address_type']
      input_value = (BigDecimal(input_data['input_value']) * 100_000_000).to_i # in sats
      sighash = nil
      
      if address_type.eql?('P2SH') then
        # P2SH addresses
        
        script = Bitcoin::Script.to_p2sh_multisig_script(input_address_data['required_signatures'], input_address_data['public_keys'])
        sighash = tx.sighash_for_input(input_index, script.last)
        
      elsif address_type.eql?('P2WSH-over-P2SH') or address_type.eql?('WITNESS_V0') then
        # P2WSH-over-P2SH addresses
        # WITNESS_V0 addresses

        script = Bitcoin::Script.to_p2sh_multisig_script(input_address_data['required_signatures'], input_address_data['public_keys'])
        sighash = tx.sighash_for_input(input_index, script.last, amount: input_value, sig_version: :witness_v0)
        
      elsif address_type.eql?('P2WPKH-over-P2SH') or address_type.eql?('P2WPKH') then
        # P2WPKH-over-P2SH addresses
        # P2WPKH addresses
        
        pub_key = Bitcoin::Key.new(:pubkey => input_address_data['public_keys'][0], :key_type => Bitcoin::Key::TYPES[:compressed]) # compressed
        script = Bitcoin::Script.to_p2wpkh(pub_key.hash160)
        sighash = tx.sighash_for_input(input_index, script, amount: input_value, sig_version: :witness_v0)
        
      elsif address_type.eql?('P2PKH') then
        # P2PKH addresses

        pub_key = Bitcoin::Key.new(:pubkey => input_address_data['public_keys'][0], :key_type => Bitcoin::Key::TYPES[:compressed]) # compressed
        script = Bitcoin::Script.to_p2pkh(pub_key.hash160)
        sighash = tx.sighash_for_input(input_index, script)

      else
        raise "Unrecognize address type: #{address_type}"
      end

      sighash
      
    end

    def self.getDecryptionAlgorithm(user_key_algorithm = nil)
      # mainly used so existing unit tests do not break
      
      algorithm = ({}).merge!(LEGACY_DECRYPTION_ALGORITHM)

      if !user_key_algorithm.nil? then
        algorithm[:pbkdf2_salt] = user_key_algorithm['pbkdf2_salt']
        algorithm[:pbkdf2_iterations] = user_key_algorithm['pbkdf2_iterations']
        algorithm[:pbkdf2_hash_function] = user_key_algorithm['pbkdf2_hash_function']
        algorithm[:pbkdf2_phase1_key_length] = user_key_algorithm['pbkdf2_phase1_key_length']
        algorithm[:pbkdf2_phase2_key_length] = user_key_algorithm['pbkdf2_phase2_key_length']
        algorithm[:aes_iv] = user_key_algorithm['aes_iv']
        algorithm[:aes_cipher] = user_key_algorithm['aes_cipher']
        algorithm[:aes_auth_tag] = user_key_algorithm['aes_auth_tag']
        algorithm[:aes_auth_data] = user_key_algorithm['aes_auth_data']
      end

      algorithm
      
    end
    
    def self.dynamicExtractKey(user_key, pin)
      # user_key object contains the encrypted user key and decryption algorithm

      algorithm = self.getDecryptionAlgorithm(user_key['algorithm'])

      aes_key = self.pinToAesKey(pin, algorithm[:pbkdf2_iterations],
                                 algorithm[:pbkdf2_salt],
                                 algorithm[:pbkdf2_hash_function],
                                 algorithm[:pbkdf2_phase1_key_length],
                                 algorithm[:pbkdf2_phase2_key_length])

      decrypted = self.decrypt(user_key['encrypted_passphrase'], aes_key, algorithm[:aes_iv], algorithm[:aes_cipher], algorithm[:aes_auth_tag], algorithm[:aes_auth_data])
      
      Key.from_passphrase(decrypted)
      
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
      OpenSSL::Digest::SHA256.digest(value).unpack1('H*')
    end
    
    def self.pinToAesKey(secret_pin, iterations = 2048, salt = '', hash_function = 'SHA256', pbkdf2_phase1_key_length = 16, pbkdf2_phase2_key_length = 32)
      # converts the pincode string to PBKDF2
      # returns a base64 version of PBKDF2 pincode

      raise Exception.new('Unknown hash function specified. Are you using current version of this library?') unless hash_function.eql?('SHA256')
      
      part1 = OpenSSL::PKCS5.pbkdf2_hmac(
        secret_pin,
        salt,
        iterations/2,
        pbkdf2_phase1_key_length,
        OpenSSL::Digest::SHA256.new
      ).unpack1('H*')
      
      part2 = OpenSSL::PKCS5.pbkdf2_hmac(
        part1,
        salt,
        iterations/2,
        pbkdf2_phase2_key_length,
        OpenSSL::Digest::SHA256.new
      ) # binary

      [part2].pack('m0') # the base64 encryption key

    end

    # Decrypts a block of data (encrypted_data) given an encryption key
    def self.decrypt(encrypted_data, b64_enc_key, iv = nil, cipher_type = 'AES-256-ECB', auth_tag = nil, auth_data = nil)

      raise Exception.new('Auth tag must be 16 bytes exactly.') unless auth_tag.nil? or auth_tag.size.eql?(32)
      
      response = nil

      begin
        aes = OpenSSL::Cipher.new(cipher_type.downcase)
        aes.decrypt
        aes.key = b64_enc_key.unpack1('m0')
        aes.iv = [iv].pack('H*') unless iv.nil?
        aes.auth_tag = [auth_tag].pack('H*') unless auth_tag.nil?
        aes.auth_data = [auth_data].pack('H*') unless auth_data.nil?
        response = aes.update(encrypted_data.unpack1('m0')) << aes.final
      rescue Exception => e
        # decryption failed, must be an invalid Secret PIN
        raise Exception.new('Invalid Secret PIN provided.')
      end

      response
    end
    
    # Encrypts a block of data given an encryption key
    def self.encrypt(data, b64_enc_key, iv = nil, cipher_type = 'AES-256-ECB', auth_data = nil)
      aes = OpenSSL::Cipher.new(cipher_type.downcase)
      aes.encrypt
      aes.key = b64_enc_key.unpack1('m0')
      aes.iv = [iv].pack('H*') unless iv.nil?
      aes.auth_data = [auth_data].pack('H*') unless auth_data.nil?
      result = [aes.update(data) << aes.final].pack('m0')
      auth_tag = (cipher_type.end_with?('-GCM') ? aes.auth_tag.unpack1('H*') : nil)

      {:aes_auth_tag => auth_tag, :aes_cipher_text => result, :aes_iv => iv, :aes_cipher => cipher_type, :aes_auth_data => auth_data}
      
    end

    # courtesy bitcoin-ruby
    BASE58_ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    def self.int_to_base58(int_val, leading_zero_bytes=0)
      base58_val, base = '', BASE58_ALPHABET.size
      while int_val > 0
        int_val, remainder = int_val.divmod(base)
        base58_val = '' << BASE58_ALPHABET[remainder] << base58_val
      end
      base58_val
    end
    
    def self.base58_to_int(base58_val)
      int_val, base = 0, BASE58_ALPHABET.size
      base58_val.reverse.each_char.with_index do |char,index|
        raise ArgumentError, 'Value not a valid Base58 String.' unless char_index = BASE58_ALPHABET.index(char)
        int_val += char_index*(base**index)
      end
      int_val
    end
    
    def self.encode_base58(hex)
      leading_zero_bytes  = (hex.match(/^([0]+)/) ? $1 : '').size / 2
      ('1'*leading_zero_bytes) << Helper.int_to_base58(hex.to_i(16))
    end
    
    def self.decode_base58(base58_val)
      s = Helper.base58_to_int(base58_val).to_s(16)
      s = (s.bytesize.odd? ? ('0' << s) : s)
      s = '' if s.eql?('00')
      leading_zero_bytes = (base58_val.match(/^([1]+)/) ? $1 : '').size
      s = ('00'*leading_zero_bytes) << s if leading_zero_bytes > 0
      s
    end
  end

end
