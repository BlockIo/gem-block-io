module BlockIo
  class Client
    def initialize(api_key: nil, pin:, hostname: 'block.io', version: 2)
      @api_key = api_key
      @pin = pin
      @hostname = hostname

      @encryptionKey = Helper.pinToAesKey(@pin) unless @pin.nil?

      @version = version
    end

    #def get_balance
      #api_call(['get_balance',""])
    #end

    def method_missing(m, *args, &block)
      method_name = m.to_s

      if ['withdraw', 'withdraw_from_address', 'withdraw_from_addresses', 'withdraw_from_user', 'withdraw_from_users', 'withdraw_from_label', 'withdraw_from_labels'].include?(m.to_s)
        # need to withdraw from an address
        withdraw(args.first, m.to_s)
      elsif ['sweep_from_address'].include?(m.to_s)
        # need to sweep from an address
        sweep(args.first, m.to_s)
      else
        params = get_params(args.first)
        api_call([method_name, params])
      end
    end

    def withdraw(args = {}, method_name = 'withdraw')
      # validate arguments for withdrawal of funds TODO

      raise Exception.new("PIN not set. Use BlockIo::Client.new(:api_key=>'API KEY',:pin=>'SECRET PIN',:version=>'API VERSION')") if @pin.nil?

      params = get_params(args)

      params << "&pin=" << @pin if @version == 1 # Block.io handles the Secret PIN in the legacy API (v1)

      response = api_call([method_name, params])

      if response['data'].has_key?('reference_id') then
        # Block.io's asking us to provide some client-side signatures, let's get to it

        # extract the passphrase
        encrypted_passphrase = response['data']['encrypted_passphrase']['passphrase']

        # let's get our private key
        key = Helper.extractKey(encrypted_passphrase, @encryptionKey)

        raise Exception.new('Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.') if key.public_key != response['data']['encrypted_passphrase']['signer_public_key']

        # let's sign all the inputs we can
        inputs = response['data']['inputs']

        Helper.signData(inputs, [key])

        # the response object is now signed, let's stringify it and finalize this withdrawal
        response = api_call(['sign_and_finalize_withdrawal',{:signature_data => Oj.dump(response['data'])}])

        # if we provided all the required signatures, this transaction went through
        # otherwise Block.io responded with data asking for more signatures
        # the latter will be the case for dTrust addresses
      end

      return response

    end

    def sweep(args = {}, method_name = 'sweep_from_address')
      # sweep coins from a given address + key

      raise Exception.new("No private_key provided.") unless args.has_key?(:private_key)

      key = Key.from_wif(args[:private_key])

      args[:public_key] = key.public_key # so Block.io can match things up
      args.delete(:private_key) # the key must never leave this machine

      params = get_params(args)

      response = api_call([method_name, params])

      if response['data'].has_key?('reference_id') then
        # Block.io's asking us to provide some client-side signatures, let's get to it

        # let's sign all the inputs we can
        inputs = response['data']['inputs']
        Helper.signData(inputs, [key])

        # the response object is now signed, let's stringify it and finalize this withdrawal
        response = api_call(['sign_and_finalize_sweep',{:signature_data => Oj.dump(response['data'])}])

        # if we provided all the required signatures, this transaction went through
        # otherwise Block.io responded with data asking for more signatures
        # the latter will be the case for dTrust addresses
      end

      return response
    end

    private

    def base_url
      @base_url ||= "https://" << @hostname << "/api/VERSION/API_CALL/?api_key="
    end

    def http_client
      @http_client ||= HTTPClient.new.tap do |h|
        h.tcp_keepalive = true
        h.ssl_config.ssl_version = :auto
      end
    end

    def api_call(endpoint)
      body = nil

      response = http_client.post("#{base_url.gsub('API_CALL',endpoint[0]).gsub('VERSION', 'v'+@version.to_s) + @api_key}", endpoint[1])

      begin
        body = Oj.load(response.body)
        raise Exception.new(body['data']['error_message']) if !body['status'].eql?('success')
      rescue
        raise Exception.new('Unknown error occurred. Please report this.')
      end

      body
    end

    def get_params(args = {})
      # construct the parameter string
      params = ""
      args = {} if args.nil?

      args.each do |k,v|
        params += '&' if params.length > 0
        params += "#{k.to_s}=#{v.to_s}"
      end

      return params
    end
  end
end
