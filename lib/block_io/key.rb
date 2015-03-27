# Private/Public key conversion functions, alongside ECDSA signature helpers

module BlockIo

  class Key

    def initialize(privkey = nil, compressed = true)
      # the privkey must be in hex if at all provided

      @group = ECDSA::Group::Secp256k1
      @private_key = privkey.to_i(16) || 1 + SecureRandom.random_number(group.order - 1)
      @public_key = @group.generator.multiply_by_scalar(@private_key)
      @compressed = compressed

    end 
    
    def private_key
      # returns private key in hex form
      @private_key.to_s(16)
    end
    alias_method :privateKey, :private_key
    alias_method :privKey, :private_key
    alias_method :privkey, :private_key
    
    def public_key
      # returns the compressed form of the public key to save network fees (shorter scripts)
      ECDSA::Format::PointOctetString.encode(@public_key, compression: @compressed).unpack("H*")[0]
    end
    alias_method :publicKey, :public_key
    alias_method :pubKey, :public_key
    alias_method :pubkey, :public_key
    
    def sign(data)
      # signed the given hexadecimal string

#      puts "SIGNING WITH PUBKEY: " << public_key

      nonce = deterministicGenerateK([data].pack("H*"), @private_key) # RFC6979
      
      signature = ECDSA.sign(@group, @private_key, data.to_i(16), nonce)

      # BIP0062 -- use lower S values only
      r, s = signature.components

      over_two = @group.order >> 1 # half of what it was                     
      s = @group.order - s if (s > over_two)

      signature = ECDSA::Signature.new(r, s)

      # DER encode this, and return it in hex form
      ECDSA::Format::SignatureDerString.encode(signature).unpack("H*")[0]
    end

    def self.from_passphrase(passphrase)
      # create a private+public key pair from a given passphrase
      # think of this as your brain wallet. be very sure to use a sufficiently long passphrase
      # if you don't want a passphrase, just use Key.new and it will generate a random key for you
      
      raise Exception.new('Must provide passphrase at least 8 characters long.') if passphrase.nil? or passphrase.length < 8
      
      # convert to hex if it isn't
      passphrase = passphrase.unpack("H*")[0] unless Helper.hex?(passphrase)

      hashed_key = Helper.sha256([passphrase].pack("H*")) # must pass bytes to sha256

      Key.new(hashed_key)
    end
    self.singleton_class.send(:alias_method, :fromPassphrase, :from_passphrase)

    def to_address(network = Vars.network)
      # converts the current key into an address for the given network
      
      raise Exception.new('Must specify a valid network.') if network.nil? or !Vars.address_versions.key?(network)

      address_sha256 = Helper.sha256([public_key].pack("H*"))
      address_ripemd160 = Digest::RMD160.hexdigest([address_sha256].pack("H*"))
      address = '' << Vars.address_versions[network] << address_ripemd160

      # calculate the checksum
      checksum = Helper.sha256([Helper.sha256([address].pack("H*"))].pack("H*"))[0,8]
      address << checksum

      Helper.encode_base58(address)
    end
    alias_method :address, :to_address
    alias_method :toAddress, :to_address

    def to_wif(network = Vars.network)
      # convert the current key to its Wallet Import Format equivalent for the given network

      raise Exception.new('Current network is unknown. Please either provide the network acronym as an argument, or initialize the library with your Block.io API Key.') if network.nil? or !Vars.privkey_versions.key?(network.upcase)
      
      curKey = '' << Vars.privkey_versions[network.upcase] << @private_key.to_s(16) 
      curKey << '01' if @compressed

      # append the first 8 bytes of the checksum
      checksum = Helper.sha256([Helper.sha256([curKey].pack("H*"))].pack("H*"))      
      curKey << checksum[0,8]

      Helper.encode_base58(curKey)
    end
    alias_method :toWIF, :to_wif
    alias_method :toWif, :to_wif

    def self.from_wif(wif)
      # returns a new key extracted from the Wallet Import Format provided

      hexkey = Helper.decode_base58(wif)

      given_checksum = hexkey.reverse[0,8].reverse
      our_checksum = Helper.sha256([Helper.sha256([hexkey[0,hexkey.size-8]].pack("H*"))].pack("H*"))[0,8]

      raise Exception.new('Invalid Private Key provided. Must be in Wallet Important Format.') unless hexkey.length >= 74 and given_checksum == our_checksum

      actual_key = hexkey[2...66]

      compressed = hexkey[2..hexkey.length].length-8 > 64 and hexkey[2..hexkey.length][64...66] == '01'

      Key.new(actual_key, compressed)
    end
    self.singleton_class.send(:alias_method, :fromWIF, :from_wif)
    self.singleton_class.send(:alias_method, :fromWif, :from_wif)

    def isPositive(i)
      sig = "!+-"[i <=> 0]
      sig.eql?("+")
    end
    
    def deterministicGenerateK(data, privkey, group = ECDSA::Group::Secp256k1)
      # returns a deterministic K  -- RFC6979

      hash = data.bytes.to_a

      x = [privkey.to_s(16)].pack("H*").bytes.to_a
      
      k = []
      32.times { k.insert(0, 0) }
      
      v = []
      32.times { v.insert(0, 1) }
      
      # step D
      k = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), [].concat(v).concat([0]).concat(x).concat(hash).pack("C*")).bytes.to_a
      
      # step E
      v = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), v.pack("C*")).bytes.to_a
      
      #  puts "E: " + v.pack("C*").unpack("H*")[0]
      
      # step F
      k = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), [].concat(v).concat([1]).concat(x).concat(hash).pack("C*")).bytes.to_a
      
      # step G
      v = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), v.pack("C*")).bytes.to_a
      
      # step H2b (Step H1/H2a ignored)
      v = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), v.pack("C*")).bytes.to_a
      
      h2b = v.pack("C*").unpack("H*")[0]
      tNum = h2b.to_i(16)
      
      # step H3
      while (!isPositive(tNum) or tNum >= group.order) do
        # k = crypto.HmacSHA256(Buffer.concat([v, new Buffer([0])]), k)
        k = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), [].concat(v).concat([0]).pack("C*")).bytes.to_a
        
        # v = crypto.HmacSHA256(v, k)
        v = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), k.pack("C*"), v.pack("C*")).bytes.to_a
        
        # T = BigInteger.fromBuffer(v)
        tNum = v.pack("C*").unpack("H*")[0].to_i(16)
      end
      
      tNum
    end

  end

end
