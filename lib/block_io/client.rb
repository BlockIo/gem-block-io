module BlockIo

  class Client

    attr_reader :api_key, :version, :network, :api_request_headers

    USER_AGENT = 'gem:block_io:' << VERSION.to_s
    CONTENT_TYPE = 'application/json; charset=UTF-8'
    ACCEPT_TYPE = 'application/json'
    KEEP_ALIVE = 'Keep-Alive'
    TIMEOUT = 60
    
    def initialize(args = {})
      # api_key
      # pin
      # version
      # hostname
      # proxy
      # pool_size
      # keys
      
      raise 'Must provide an API Key.' unless args.key?(:api_key) and args[:api_key].to_s.size > 0
      
      @api_key = args[:api_key]
      @pin = args[:pin]
      @version = args[:version] || 2
      @hostname = args[:hostname] || 'block.io'
      @keys = {}

      # prepare proxy settings if provided
      proxy = args[:proxy] || {}

      if proxy.keys.size > 0 then
        raise Exception.new('Must specify hostname, port, username, password if using a proxy.') if [:url, :username, :password].any?{|x| !proxy.key?(x)}
        @proxy = {:proxy => proxy[:url], :proxyuserpwd => "#{proxy[:username]}:#{proxy[:password]}"}.freeze
      else
        @proxy = {}
      end

      @api_request_headers = {'User-Agent' => USER_AGENT, 'Content-Type' => CONTENT_TYPE, 'Accept' => ACCEPT_TYPE, 'Expect' => '', 'Connection' => KEEP_ALIVE, 'Host' => @hostname}.freeze
      
      # this will get populated after a successful API call
      @network = nil

    end

    def method_missing(m, *args)
      
      method_name = m.to_s

      raise Exception.new('Must provide arguments as a Hash.') unless args.size <= 1 and args.all?{|x| x.is_a?(Hash)}
      raise Exception.new('Parameter keys must be symbols. For instance: :label => "default" instead of "label" => "default"') unless args[0].nil? or args[0].keys.all?{|x| x.is_a?(Symbol)}
      raise Exception.new('Cannot pass PINs to any calls. PINs can only be set when initiating this library.') if !args[0].nil? and args[0].key?(:pin)
      raise Exception.new('Do not specify API Keys here. Initiate a new BlockIo object instead if you need to use another API Key.') if !args[0].nil? and args[0].key?(:api_key)

      if method_name.eql?('prepare_sweep_transaction') then
        # we need to ensure @network is set before we allow this
        # we need to send only the public key, not the given private key
        # we're sweeping from an address
        internal_prepare_sweep_transaction(args[0], method_name)
      else
        api_call({:method_name => method_name, :params => args[0] || {}})
      end
      
    end

    def padded_f(d)
      # returns a padded decimal to 8 decimal places
      b = BigDecimal(d).to_s('F')
      b << '0' * (8 - (b.size - b.index('.') - 1))
      b
    end
    
    def summarize_prepared_transaction(data)
      # takes the response from prepare_transaction/prepare_dtrust_transaction/prepare_sweep_transaction
      # returns the network fee being paid, the blockio fee being paid, amounts being sent

      input_sum = data['data']['inputs'].map{|input| BigDecimal(input['input_value'])}.inject(:+)

      output_values = [BigDecimal(0)]
      blockio_fees = [BigDecimal(0)]
      change_amounts = [BigDecimal(0)]

      i = 0
      loop do
        output = data['data']['outputs'][i]
        break if output.nil?
        i += 1

        if output['output_category'].eql?('blockio-fee') then
          blockio_fees << BigDecimal(output['output_value'])
        elsif output['output_category'].eql?('change') then
          change_amounts << BigDecimal(output['output_value'])
        else
          # user-specified
          output_values << BigDecimal(output['output_value'])
        end
      end
      
      output_sum = output_values.inject(:+)
      blockio_fee = blockio_fees.inject(:+)
      change_amount = change_amounts.inject(:+)
      
      network_fee = input_sum - output_sum - blockio_fee - change_amount

      {
        'network' => data['data']['network'],
        'network_fee' => padded_f(network_fee),
        'blockio_fee' => padded_f(blockio_fee),
        'total_amount_to_send' => padded_f(output_sum)
      }
      
    end
    
    def create_and_sign_transaction(data, keys = [])
      # takes data from prepare_transaction, prepare_dtrust_transaction, prepare_sweep_transaction
      # creates the transaction given the inputs and outputs from data
      # signs the transaction using keys (if not provided, decrypts the key using the PIN)
      
      set_network(data['data']['network']) if data['data'].key?('network')

      raise 'Data must be contain one or more inputs' unless data['data']['inputs'].size > 0
      raise 'Data must contain one or more outputs' unless data['data']['outputs'].size > 0
      raise 'Data must contain information about addresses' unless data['data']['input_address_data'].size > 0 # TODO make stricter

      private_keys = keys.map{|x| Key.from_private_key_hex(x)}

      inputs = data['data']['inputs']
      outputs = data['data']['outputs']

      tx = Bitcoin::Tx.new

      # populate the inputs
      tx.in << inputs.map do |input|
        Bitcoin::TxIn.new(:out_point => Bitcoin::OutPoint.from_txid(input['previous_txid'], input['previous_output_index']))
      end
      tx.in.flatten!
      
      # populate the outputs
      tx.out << outputs.map do |output|
        Bitcoin::TxOut.new(:value => (BigDecimal(output['output_value']) * BigDecimal(100000000)).to_i, :script_pubkey => Bitcoin::Script.parse_from_addr(output['receiving_address']))
      end
      tx.out.flatten!
      
      # some protection against misbehaving machines and/or code
      raise Exception.new('Expected unsigned transaction ID mismatch. Please report this error to support@block.io.') unless (data['data']['expected_unsigned_txid'].nil? or
                                                                                                                              data['data']['expected_unsigned_txid'].eql?(tx.txid))

      # extract key
      encrypted_key = data['data']['user_key']

      if !encrypted_key.nil? and !@keys.key?(encrypted_key['public_key']) then
        # decrypt the key with PIN

        raise Exception.new('PIN not set and no keys provided. Cannot sign transaction.') unless !@pin.nil? or @keys.size > 0

        key = Helper.dynamicExtractKey(encrypted_key, @pin)

        raise Exception.new('Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.') unless key.public_key_hex.eql?(encrypted_key['public_key'])

        # store this key for later use
        @keys[key.public_key_hex] = key
        
      end

      # store the provided keys, if any, for later use
      @keys.merge!(private_keys.map{|key| [key.public_key_hex, key]}.to_h)
      
      signatures = []
      
      if @keys.size > 0 then
        # try to sign whatever we can here and give the user the data back
        # Block.io will check to see if all signatures are present, or return an error otherwise saying insufficient signatures provided

        i = 0
        loop do
          input = inputs[i]
          break if input.nil?

          input_address_data = data['data']['input_address_data'].detect{|d| d['address'].eql?(input['spending_address'])}
          sighash_for_input = Helper.getSigHashForInput(tx, i, input, input_address_data) # in bytes

          signatures << input_address_data['public_keys'].map do |signer_public_key|
            # sign what we can and append signatures to the signatures object
            next unless @keys.key?(signer_public_key)
            
            {
              'input_index' => i,
              'public_key' => signer_public_key,
              'signature' => @keys[signer_public_key].sign(sighash_for_input).unpack1('H*') # in hex
            }
          end

          i += 1 # go to next input
        end
        
      end

      signatures.flatten!
      signatures.compact!
      
      # if we have everything we need for this transaction, just finalize the transaction
      if Helper.allSignaturesPresent?(tx, inputs, signatures, data['data']['input_address_data']) then
        Helper.finalizeTransaction(tx, inputs, signatures, data['data']['input_address_data'])
        signatures = [] # no signatures left to append
      end

      # reset keys
      @keys = {}
      
      # the response for submitting the transaction
      {'tx_type' => data['data']['tx_type'], 'tx_hex' => tx.to_hex, 'signatures' => (signatures.size.eql?(0) ? nil : signatures)}
      
    end

    private

    def internal_prepare_sweep_transaction(args = {}, method_name = 'prepare_sweep_transaction')

      # set the network first if not already known
      api_call({:method_name => 'get_balance', :params => {}}) if @network.nil?

      raise Exception.new('No private_key provided.') unless args.key?(:private_key) and (args[:private_key] || '').size > 0

      # ensure the private key never goes to Block.io
      key = Key.from_wif(args[:private_key])
      sanitized_args = args.merge({:public_key => key.public_key_hex})
      sanitized_args.delete(:private_key)

      @keys[key.public_key_hex] = key # store this in our set of keys for later use
      
      api_call({:method_name => method_name, :params => sanitized_args})
      
    end

    def set_network(network)
      # load the chain_params for this network
      @network ||= network
      Bitcoin.chain_params = @network unless @network.to_s.size == 0
    end
    
    def api_call(args)

      response = Typhoeus.post("https://#{@hostname}/api/v#{@version}/#{args[:method_name]}",
                               :body => Oj.dump(args[:params].merge({:api_key => @api_key}), :mode => :compat),
                               :headers => @api_request_headers,
                               :timeout => TIMEOUT,
                               **@proxy)

      body = nil
      
      if response.timed_out? then
        body = {'status' => 'fail', 'data' => {'error_message' => 'Request timed out.'}}
      elsif response.code.eql?(0) then
        body = {'status' => 'fail', 'data' => {'error_message' => 'No response received.'}}
      else
        begin
          body = Oj.safe_load(response.body.to_s)
        rescue Exception => e
          body = {'status' => 'fail', 'data' => {'error_message' => "Unknown error occurred. Please report this to support@block.io. Status #{response.code}."}}
        end
      end
      
      if !body['status'].eql?('success') then
        # raise an exception on error for easy handling
        # user can extract raw response using e.raw_data
        e = APIException.new(body['data']['error_message'].to_s)
        e.set_raw_data(body)
        raise e
      end

      # success
      set_network(body['data']['network']) if body['data'].key?('network')
      body
      
    end
        
  end
  
end
