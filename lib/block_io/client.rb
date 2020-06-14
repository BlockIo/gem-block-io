module BlockIo

  class Client

    attr_reader :api_key, :version, :network

    def initialize(args = {})

      raise "Must provide an API Key." unless args.key?(:api_key) and args[:api_key].to_s.size > 0
      
      @api_key = args[:api_key]
      @encryption_key = Helper.pinToAesKey(args[:pin] || "") if args.key?(:pin)
      @version = args[:version] || 2
      @base_url = "https://#{args[:hostname] || "block.io"}/api/v#{@version}"

      @network = Helper.api_call({:base_url => @base_url, :api_key => @api_key, :method_name => "get_address_balance", :params => {:label => "default"}})['data']['network']
      
    end

    def method_missing(m, *args, &blocks)
      
      method_name = m.to_s

      raise Exception.new("Parameter keys must be symbols. For instance: :label => 'default' instead of 'label' => 'default'") unless args[0].nil? or args[0].keys.all?{|x| x.is_a?(Symbol)}
      raise Exception.new("Cannot pass PINs to any calls. PINs can only be set when initiating this library.") if !args[0].nil? and args[0].key?(:pin)
      
      if BlockIo::WITHDRAW_METHODS.include?(method_name) then
        # it's a withdrawal call
        withdraw(args[0], method_name)
      elsif BlockIo::SWEEP_METHODS.include?(method_name) then
        # we're sweeping from an address
        sweep(args[0], method_name)
      else
        Helper.api_call({:base_url => @base_url, :api_key => @api_key, :method_name => method_name, :params => args[0] || {}})
      end
      
    end

    private

    def withdraw(args = {}, method_name = "withdraw")

      raise Exception.new("PIN not set. Cannot execute withdrawal requests.") unless @encryption_key

      response = Helper.api_call({:base_url => @base_url, :api_key => @api_key, :method_name => method_name, :params => args})

      if response["data"].key?("reference_id") then
        # Block.io's asking us to provide client-side signatures

        # extract the passphrase
        encrypted_passphrase = response['data']['encrypted_passphrase']['passphrase']

        # let's get our private key
        key = Helper.extractKey(encrypted_passphrase, @encryption_key)

        raise Exception.new('Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.') if key.public_key != response["data"]["encrypted_passphrase"]["signer_public_key"]
        
        # let's sign all the inputs we can
        inputs = response['data']['inputs']
        
        Helper.signData(inputs, [key])
        
        # the response object is now signed, let's stringify it and finalize this withdrawal

        response["data"].delete("encrypted_passphrase")
        response["data"].delete("unsigned_tx_hex")
        
        response = Helper.api_call({:base_url => @base_url, :api_key => @api_key, :method_name => "sign_and_finalize_withdrawal", :params => {:signature_data => Oj.dump(response['data'])}})
        
        # if we provided all the required signatures, this transaction went through
        # otherwise Block.io responded with data asking for more signatures
        # the latter will be the case for dTrust addresses
      end

      response

    end

    def sweep(args = {}, method_name = "sweep_from_address")
      # sweep coins from a given address and key

      raise Exception.new("No private_key provided.") unless args.key?(:private_key)

      key = Key.from_wif(args[:private_key])

      response = Helper.api_call({:base_url => @base_url, :api_key => @api_key, :method_name => method_name, :params => args.merge({:public_key => key.public_key}).delete(:private_key)})

      if response["data"].key?("reference_id") then
        # Block.io's asking us to provide client-side signatures

        inputs = response["data"]["inputs"]

        # let's sign all the inputs we can
        Helper.signData(inputs, [key])

        # the response object is now signed, let's stringify it and finalize this transaction
        response = Helper.api_call({:base_url => @base_url, :api_key => @api_key, :method_name => "sign_and_finalize_sweep", :params => {:signature_data => Oj.dump(response['data'])}})

        # if we provided all the required signatures, this transaction went through
      end

      response

    end
    
  end
  
end
