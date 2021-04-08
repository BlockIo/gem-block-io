module BlockIo

  class Key

    def self.generate
      # returns a new key
      Bitcoin::Key.generate(:compressed)
    end
    
    def self.from_passphrase(passphrase)
      # ATTENTION: use BlockIo::Key.new to generate new private keys. Using passphrases is not recommended due to lack of / low entropy.
      # create a private/public key pair from a given passphrase
      # use a long, random passphrase. your security depends on the passphrase's entropy.
      
      raise Exception.new("Must provide passphrase at least 8 characters long.") if passphrase.nil? or passphrase.length < 8
      
      hashed_key = Helper.sha256([passphrase].pack("H*")) # must pass bytes to sha256
      
      # modding is for backward compatibility with legacy bitcoinjs
      Bitcoin::Key.new(:priv_key => (hashed_key.to_i(16) % ECDSA::Group::Secp256k1.order).to_s(16), :key_type => :compressed)
    end

    def self.from_wif(wif)
      # returns a new key extracted from the Wallet Import Format provided

      Bitcoin::Key.from_wif(wif)

    end

  end
  
end
