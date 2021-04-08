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
      @raise_exception_on_error = args[:raise_exception_on_error] || false

      raise Exception.new("Keys must be provided as an array.") unless @keys.is_a?(Array)
      raise Exception.new("Keys must be BlockIo::Key objects.") unless @keys.all?{|key| key.is_a?(BlockIo::Key)}

      # make a hash of the keys we've been given
      @keys = @keys.inject({}){|h,v| h[v.pubkey] = v; h}
      
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
      
      api_call({:method_name => method_name, :params => args[0] || {}})
      
    end

    # TODO do sweep and dtrust
    
    def create_and_sign_transaction(data, keys = [])
      # takes data from prepare_transaction
      # creates the transaction given the inputs and outputs from data
      # signs the transaction using keys (if not provided, decrypts the key using the PIN)

      raise "Data must be contain one or more inputs" unless data['data']['inputs'].size > 0
      raise "Data must contain one or more outputs" unless data['data']['outputs'].size > 0
      raise "Data must contain information about addresses" unless data['data']['input_address_data'].size > 0 # TODO make stricter
      # TODO debug all of this
      
      # load the chain parameters for this network
      Bitcoin.chain_params = @network

      inputs = data['data']['inputs']
      outputs = data['data']['outputs']

      tx = Bitcoin::Tx.new

      # populate the inputs
      inputs.each do |input|
        tx.in << Bitcoin::TxIn.new(:out_point => Bitcoin::OutPoint.from_txid(input['previous_txid'], input['previous_output_index']))
      end

      # populate the outputs
      outputs.each do |output|
        tx.out << Bitcoin::TxOut.new(:value => (BigDecimal(output['output_value']) * BigDecimal(100000000)).to_i, :script_pubkey => Bitcoin::Script.parse_from_addr(output['receiving_address']))
      end

      # extract key
      encrypted_key = data['data']['user_key']

      if !encrypted_key.nil? and !@keys.key?(encrypted_key['public_key']) then
        # decrypt the key with PIN

        raise Exception.new("PIN not set and no keys provided. Cannot sign transaction.") unless @encryption_key or @keys.size > 0
        
        key = Helper.extractKey(encrypted_key['encrypted_passphrase'], @encryption_key)
        raise Exception.new("Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.") unless key.pubkey.eql?(encrypted_key["public_key"])

        # store this key for later use
        @keys[key.pubkey] = key
      end

      signatures = []
      
      if @keys.size > 0 then
        # try to sign whatever we can here and give the user the data back
        # Block.io will check to see if all signatures are present, or return an error otherwise saying insufficient signatures provided

        i = 0
        while i < inputs.size do
          input = inputs[i]

          input_address_data = data['data']['input_address_data'].detect{|d| d['address'] == input['spending_address']}
          sighash_for_input = Helper.getSigHashForInput(tx, i, input, input_address_data) # in bytes

          input_address_data['public_keys'].each do |signer_public_key|
            # sign what we can and append signatures to the signatures object
            
            next unless @keys.key?(signer_public_key)
            
            signature = @keys[signer_public_key].sign(sighash_for_input).unpack("H*")[0] # in hex
            signatures << {:input_index => i, :public_key => signer_public_key, :signature => signature, :sighash => sighash_for_input.unpack("H*")[0]}
            
          end

          i += 1 # go to next input
        end
        
      end

      # the response for submitting the transaction
      {:tx_hex => tx.to_hex, :signatures => signatures}
      
    end

    def submit_transaction(data)
      # submits minimal data from create_and_sign_transaction's response

      api_call({:method_name => method_name, :params => {:transaction_data => Oj.dump(data)}})
      
    end
    
    private

    def api_call(args)

      raise Exception.new("No connections left to perform API call. Please re-initialize BlockIo::Client with :pool_size greater than #{@conn.size}.") unless @conn.available > 0
      
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
