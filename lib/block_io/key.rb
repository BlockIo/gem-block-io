module BlockIo

  class Key

    def initialize(privkey = nil, compressed = true)
      # the privkey must be in hex if at all provided

      @group = ECDSA::Group::Secp256k1
      @private_key = (privkey.nil? ? (1 + SecureRandom.random_number(@group.order - 1)) : privkey.to_i(16))
      @public_key = @group.generator.multiply_by_scalar(@private_key)
      @compressed = compressed

    end 
    
    def private_key
      # returns private key in hex form
      @private_key.to_s(16)
    end
    
    def public_key
      # returns the compressed form of the public key to save network fees (shorter scripts)
      # hex form
      ECDSA::Format::PointOctetString.encode(@public_key, compression: @compressed).unpack("H*")[0]
    end
    
    def sign(data)
      # sign the given hexadecimal string

      nonce = Key.deterministicGenerateK([data].pack("H*"), @private_key) # RFC6979
      
      signature = ECDSA.sign(@group, @private_key, data.to_i(16), nonce)

      # BIP0062 -- use lower S values only
      r, s = signature.components

      over_two = @group.order >> 1 # half of what it was                     
      s = @group.order - s if (s > over_two)

      signature = ECDSA::Signature.new(r, s)

      # DER encode this, and return it in hex form
      ECDSA::Format::SignatureDerString.encode(signature).unpack("H*")[0]
    end

    def valid_signature?(signature, data)
      ECDSA.valid_signature?(@public_key, [data].pack("H*"), ECDSA::Format::SignatureDerString.decode([signature].pack("H*")))
    end
    
    def self.from_passphrase(passphrase)
      # create a private/public key pair from a given passphrase
      # think of this as your brain wallet. be very sure to use a sufficiently long passphrase
      # if you don't want a passphrase, just use Key.new and it will generate a random key for you
      
      raise Exception.new("Must provide passphrase at least 8 characters long.") if passphrase.nil? or passphrase.length < 8
      
      hashed_key = Helper.sha256([passphrase].pack("H*")) # must pass bytes to sha256

      Key.new(hashed_key)
    end

    def self.from_wif(wif)
      # returns a new key extracted from the Wallet Import Format provided
      # TODO check against checksum

      hexkey = Helper.decode_base58(wif)
      actual_key = hexkey[2...66]

      compressed = hexkey[2..hexkey.length].length-8 > 64 and hexkey[2..hexkey.length][64...66] == "01"

      Key.new(actual_key, compressed)

    end

    private
    
    def self.isPositive(i)
      sig = "!+-"[i <=> 0]
      
      sig.eql?("+")
    end
    
    def self.deterministicGenerateK(data, privkey, group = ECDSA::Group::Secp256k1)
      # returns a deterministic K  -- RFC6979

      hash = data.bytes.to_a

      x = [privkey.to_s(16)].pack("H*").bytes.to_a
      
      k = [0] * 32      
      v = [1] * 32
      
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
