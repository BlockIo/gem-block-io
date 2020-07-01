module BlockIo

  class Client

    attr_reader :api_key, :version, :network

    def initialize(args = {})
      # api_key
      # pin
      # version
      # hostname
      # proxy
      # pool_size
      # keys
      
      raise "Must provide an API Key." unless args.key?(:api_key) and args[:api_key].to_s.size > 0
      
      @api_key = args[:api_key]
      @encryption_key = Helper.pinToAesKey(args[:pin] || "") if args.key?(:pin)
      @version = args[:version] || 2
      @hostname = args[:hostname] || "block.io"
      @proxy = args[:proxy] || {}
      @keys = args[:keys] || []
      @use_low_r = args[:use_low_r]
      @raise_exception_on_error = args[:raise_exception_on_error] || false

      raise Exception.new("Keys must be provided as an array.") unless @keys.is_a?(Array)
      raise Exception.new("Keys must be BlockIo::Key objects.") unless @keys.all?{|key| key.is_a?(BlockIo::Key)}

      # make a hash of the keys we've been given
      @keys = @keys.inject({}){|h,v| h[v.public_key] = v; h}
      
      raise Exception.new("Must specify hostname, port, username, password if using a proxy.") if @proxy.keys.size > 0 and [:hostname, :port, :username, :password].any?{|x| !@proxy.key?(x)}

      @conn = ConnectionPool.new(:size => args[:pool_size] || 5) { http = HTTP.headers(:accept => "application/json", :user_agent => "gem:block_io:#{VERSION}");
        http = http.via(args.dig(:proxy, :hostname), args.dig(:proxy, :port), args.dig(:proxy, :username), args.dig(:proxy, :password)) if @proxy.key?(:hostname);
        http = http.persistent("https://#{@hostname}");
        http }
      
      # this will get populated after a successful API call
      @network = nil

    end

    def method_missing(m, *args)
      
      method_name = m.to_s

      raise Exception.new("Must provide arguments as a Hash.") unless args.size <= 1 and args.all?{|x| x.is_a?(Hash)}
      raise Exception.new("Parameter keys must be symbols. For instance: :label => 'default' instead of 'label' => 'default'") unless args[0].nil? or args[0].keys.all?{|x| x.is_a?(Symbol)}
      raise Exception.new("Cannot pass PINs to any calls. PINs can only be set when initiating this library.") if !args[0].nil? and args[0].key?(:pin)
      raise Exception.new("Do not specify API Keys here. Initiate a new BlockIo object instead if you need to use another API Key.") if !args[0].nil? and args[0].key?(:api_key)
      
      if BlockIo::WITHDRAW_METHODS.key?(method_name) then
        # it's a withdrawal call
        withdraw(args[0], method_name)
      elsif BlockIo::SWEEP_METHODS.key?(method_name) then
        # we're sweeping from an address
        sweep(args[0], method_name)
      elsif BlockIo::FINALIZE_SIGNATURE_METHODS.key?(method_name) then
        # we're finalize the transaction signatures
        finalize_signature(args[0], method_name)
      else
        api_call({:method_name => method_name, :params => args[0] || {}})
      end
      
    end

    private

    def withdraw(args = {}, method_name = "withdraw")      

      response = api_call({:method_name => method_name, :params => args})

      if response["data"].key?("reference_id") then
        # Block.io's asking us to provide client-side signatures

        encrypted_passphrase = response["data"]["encrypted_passphrase"]

        if !encrypted_passphrase.nil? and !@keys.key?(encrypted_passphrase["signer_public_key"]) then
          # encrypted passphrase was provided, and we do not have the signer's key, so let's extract it first

          raise Exception.new("PIN not set and no keys provided. Cannot execute withdrawal requests.") unless @encryption_key or @keys.size > 0

          key = Helper.extractKey(encrypted_passphrase["passphrase"], @encryption_key, @use_low_r)
          raise Exception.new("Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.") unless key.public_key.eql?(encrypted_passphrase["signer_public_key"])

          # store this key for later use
          @keys[key.public_key] = key

        end

        if @keys.size > 0 then
          # if we have at least one key available, try to send signatures back
          # if a dtrust withdrawal is used without any keys stored in the BlockIo::Client object, the output of this call will be the previous response from Block.io
          
          # we just need reference_id and inputs
          response["data"] = {"reference_id" => response["data"]["reference_id"], "inputs" => response["data"]["inputs"]}
        
          # let's sign all the inputs we can
          signatures_added = (@keys.size == 0 ? false : Helper.signData(response["data"]["inputs"], @keys))
          
          # the response object is now signed, let's stringify it and finalize this withdrawal
          response = finalize_signature({:signature_data => response["data"]}, "sign_and_finalize_withdrawal") if signatures_added
          
          # if we provided all the required signatures, this transaction went through
          # otherwise Block.io responded with data asking for more signatures and recorded the signature we provided above
          # the latter will be the case for dTrust addresses
        end
        
      end

      response

    end

    def sweep(args = {}, method_name = "sweep_from_address")
      # sweep coins from a given address and key

      raise Exception.new("No private_key provided.") unless args.key?(:private_key) and (args[:private_key] || "").size > 0

      key = Key.from_wif(args[:private_key], @use_low_r)
      sanitized_args = args.merge({:public_key => key.public_key})
      sanitized_args.delete(:private_key)
      
      response = api_call({:method_name => method_name, :params => sanitized_args})
      
      if response["data"].key?("reference_id") then
        # Block.io's asking us to provide client-side signatures

        # we just need the reference_id and inputs
        response["data"] = {"reference_id" => response["data"]["reference_id"], "inputs" => response["data"]["inputs"]}
        
        # let's sign all the inputs we can
        signatures_added = Helper.signData(response["data"]["inputs"], [key])

        # the response object is now signed, let's stringify it and finalize this transaction
        response = finalize_signature({:signature_data => response["data"]}, "sign_and_finalize_sweep") if signatures_added

        # if we provided all the required signatures, this transaction went through
      end

      response

    end

    def finalize_signature(args = {}, method_name = "sign_and_finalize_withdrawal")

      raise Exception.new("Object must have reference_id and inputs keys.") unless args.key?(:signature_data) and args[:signature_data].key?("inputs") and args[:signature_data].key?("reference_id")

      signatures = {"reference_id" => args[:signature_data]["reference_id"], "inputs" => args[:signature_data]["inputs"]}

      response = api_call({:method_name => method_name, :params => {:signature_data => Oj.dump(signatures)}})
      
    end
    
    def api_call(args)

      response = @conn.with {|http| http.post("/api/v#{@version}/#{args[:method_name]}", :json => args[:params].merge({:api_key => @api_key}))}

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
