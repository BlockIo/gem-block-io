require 'yaml'

module Bitcoin

  # set network chain params
  def self.chain_params=(name)
    raise "chain params for #{name} is not defined." unless %i(BTC DOGE LTC BTCTEST DOGETEST LTCTEST).include?(name.to_sym)
    @current_chain = nil
    @chain_param = name.to_sym
  end
  
  # current network chain params.
  def self.chain_params
    return @current_chain if @current_chain
    return (@current_chain = Bitcoin::ChainParams.get(@chain_param.to_s))
  end
  
  class ChainParams
    def self.get(network)
      init(network)
    end

    def self.init(name)
      i = YAML.load(File.open("#{__dir__}/chainparams/#{name}.yml"))
      i.dust_relay_fee ||= Bitcoin::DUST_RELAY_TX_FEE
      i
    end
  end

  module Secp256k1
    module Ruby

      module_function
      
      def sign_ecdsa(data, privkey, extra_entropy)
        privkey = privkey.htb
        private_key = ECDSA::Format::IntegerOctetString.decode(privkey)
        extra_entropy ||= ''
        nonce = RFC6979.generate_rfc6979_nonce(privkey + data, extra_entropy)
        
        # port form ecdsa gem.
        r_point = GROUP.new_point(nonce)
        
        point_field = ECDSA::PrimeField.new(GROUP.order)
        r = point_field.mod(r_point.x)
        return nil if r.zero?
        
        e = ECDSA.normalize_digest(data, GROUP.bit_length)
        s = point_field.mod(point_field.inverse(nonce) * (e + r * private_key))
        
        if s > (GROUP.order / 2) # convert low-s
          s = GROUP.order - s
        end
        
        return nil if s.zero?
        
        signature = ECDSA::Signature.new(r, s).to_der
        
        public_key = Bitcoin::Key.new(priv_key: privkey.bth, key_type: :compressed).pubkey # suppress key_type != :compressed warnings
        
        raise 'Creation of signature failed.' unless Bitcoin::Secp256k1::Ruby.verify_sig(data, signature, public_key)
        signature
      end
            
    end
  end
  
  class Key

    def initialize(priv_key: nil, pubkey: nil, key_type: nil, compressed: true, allow_hybrid: false)
      # override so enforce compressed keys
      
      raise "key_type must always be compressed" unless key_type == :compressed or key_type == TYPES[:compressed]
      puts "[Warning] Use key_type parameter instead of compressed. compressed parameter removed in the future." if key_type.nil? && !compressed.nil? && pubkey.nil?
      if key_type
        @key_type = key_type
        compressed = @key_type != TYPES[:uncompressed]
      else
        @key_type = compressed ? TYPES[:compressed] : TYPES[:uncompressed]
      end
      @secp256k1_module =  Bitcoin.secp_impl
      @priv_key = priv_key
      if @priv_key
        raise ArgumentError, Errors::Messages::INVALID_PRIV_KEY unless validate_private_key_range(@priv_key)
      end
      if pubkey
        @pubkey = pubkey
      else
        @pubkey = generate_pubkey(priv_key, compressed: compressed) if priv_key
      end
      raise ArgumentError, Errors::Messages::INVALID_PUBLIC_KEY unless fully_valid_pubkey?(allow_hybrid)
    end
    
  end
  
end

module Bech32
  # override so we can parse non-Bitcoin Bech32 addresses
  
  class SegwitAddr
    
    private
    def parse_addr(addr)
      @hrp, data, spec = Bech32.decode(addr)
      raise 'Invalid address.' if hrp.nil? || data[0].nil? || !['bc', 'ltc', 'tb', 'tltc', 'doge', 'tdge'].include?(hrp) # HRP_MAINNET, HRP_TESTNET, HRP_REGTEST].include?(hrp)
      @ver = data[0]
      raise 'Invalid witness version' if @ver > 16
      @prog = convert_bits(data[1..-1], 5, 8, false)
      raise 'Invalid witness program' if @prog.nil? || @prog.length < 2 || @prog.length > 40
      raise 'Invalid witness program with version 0' if @ver == 0 && (@prog.length != 20 && @prog.length != 32)
      raise 'Witness version and encoding spec do not match' if (@ver == 0 && spec != Bech32::Encoding::BECH32) || (@ver != 0 && spec != Bech32::Encoding::BECH32M)
    end
        
  end
  
end

