module BlockIo

  class Client

    attr_reader :api_key, :version, :network

    def initialize(args = {})

      raise "Must provide an API Key." unless args.key?(:api_key) and args[:api_key].to_s.size > 0
      
      @api_key = args[:api_key]
      @encryption_key = Helper.pinToAesKey(args[:pin] || "") if args.key?(:pin)
      @version = args[:version] || 2
      @base_url = "https://#{args[:hostname] || "block.io"}/api/v#{@version}"
      @proxy = args[:proxy] || {}
      @raise_exception_on_error = args[:raise_exception_on_error] || false

      raise Exception.new("Must specify hostname, port, username, password if using a proxy.") if @proxy.keys.size > 0 and [:hostname, :port, :username, :password].any?{|x| !@proxy.key?(x)}
      
      @http = HTTP.headers(:accept => "application/json", :user_agent => "gem:block_io:#{VERSION}")
      @http = @http.via(args[:proxy][:hostname], :args[:proxy][:port], :args[:proxy][:username], :args[:proxy][:password]) if @proxy.key?(:hostname)

      # this will get populated after a successful API call
      @network = nil

    end

    def method_missing(m, *args)
      
      method_name = m.to_s

      raise Exception.new("Must provide arguments as a Hash.") unless args.size <= 1 and args.all?{|x| x.is_a?(Hash)}
      raise Exception.new("Parameter keys must be symbols. For instance: :label => 'default' instead of 'label' => 'default'") unless args[0].nil? or args[0].keys.all?{|x| x.is_a?(Symbol)}
      raise Exception.new("Cannot pass PINs to any calls. PINs can only be set when initiating this library.") if !args[0].nil? and args[0].key?(:pin)
      raise Exception.new("Initiate a new BlockIo object to specify another API Key.") if !args[0].nil? and args[0].key?(:api_key)
      
      if BlockIo::WITHDRAW_METHODS.key?(method_name) then
        # it's a withdrawal call
        withdraw(args[0], method_name)
      elsif BlockIo::SWEEP_METHODS.key?(method_name) then
        # we're sweeping from an address
        sweep(args[0], method_name)
      else
        api_call({:method_name => method_name, :params => args[0] || {}})
      end
      
    end

    private

    def withdraw(args = {}, method_name = "withdraw")

      raise Exception.new("PIN not set. Cannot execute withdrawal requests.") unless @encryption_key

      response = api_call({:method_name => method_name, :params => args})

      if response["data"].key?("reference_id") then
        # Block.io's asking us to provide client-side signatures

        # extract the passphrase
        encrypted_passphrase = response["data"]["encrypted_passphrase"]

        # we just need reference_id and inputs
        response["data"] = {"reference_id" => response["data"]["reference_id"], "inputs" => response["data"]["inputs"]}
        
        # let's get our private key
        key = Helper.extractKey(encrypted_passphrase["passphrase"], @encryption_key)

        raise Exception.new("Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.") unless key.public_key.eql?(encrypted_passphrase["signer_public_key"])
        
        # let's sign all the inputs we can
        Helper.signData(response["data"]["inputs"], [key])
        
        # the response object is now signed, let's stringify it and finalize this withdrawal
        response = api_call({:method_name => "sign_and_finalize_withdrawal", :params => {:signature_data => Oj.dump(response['data'])}})
        
        # if we provided all the required signatures, this transaction went through
        # otherwise Block.io responded with data asking for more signatures and recorded the signature we provided above
        # the latter will be the case for dTrust addresses

      end

      response

    end

    def sweep(args = {}, method_name = "sweep_from_address")
      # sweep coins from a given address and key

      raise Exception.new("No private_key provided.") unless args.key?(:private_key) and (args[:private_key] || "").size > 0

      key = Key.from_wif(args.delete(:private_key))

      response = api_call({:method_name => method_name, :params => args.merge!({:public_key => key.public_key})})
      args.delete(:public_key)
      
      if response["data"].key?("reference_id") then
        # Block.io's asking us to provide client-side signatures

        # we just need the reference_id and inputs
        response["data"] = {"reference_id" => response["data"]["reference_id"], "inputs" => response["data"]["inputs"]}
        
        # let's sign all the inputs we can
        Helper.signData(response["data"]["inputs"], [key])

        # the response object is now signed, let's stringify it and finalize this transaction
        response = api_call({:method_name => "sign_and_finalize_sweep", :params => {:signature_data => Oj.dump(response["data"])}})

        # if we provided all the required signatures, this transaction went through
      end

      response

    end

    def api_call(args)

      response = @http.post("#{@base_url}/#{args[:method_name]}", :json => args[:params].merge!({:api_key => @api_key}))
      args[:params].delete(:api_key)
      
      begin
        body = Oj.safe_load(response.to_s)
      rescue
        body = {"status" => "fail", "data" => {"error_message" => "Unknown error occurred. Please report this to support@block.io. Status #{response.code}."}}
      end

      raise Exception.new("#{body["data"]["error_message"]}") if !body["status"].eql?("success") and @raise_exception_on_error

      @network ||= body["data"]["network"] if body["data"].key?("network")
      
      body
      
    end
        
  end
  
end
