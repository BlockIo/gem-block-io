describe "Client.prepare_sweep_transaction" do

  before(:each) do
    @api_key = "0000-0000-0000-0000"
    @wif = "cTj8Ydq9LhZgttMpxb7YjYSqsZ2ZfmyzVprQgjEzAzQ28frQi4ML" # insecure, do not use!
    @req_params = {:to_address => "QTLcyTFrH7T6kqUsi1VV2mJVXmX3AmwUNH", :public_key => "021499295873879c280c31fff94845a6153142e76b84a29afc92128d482857ed93"}
    @req_params_with_wif = {:to_address => "QTLcyTFrH7T6kqUsi1VV2mJVXmX3AmwUNH", :private_key => @wif}

    @headers = {
      'Accept' => 'application/json',
      'Connection' => 'Keep-Alive',
      'Content-Type' => 'application/json; charset=UTF-8',
      'Host' => 'block.io',
      'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
    }

    # since @network won't be set, the library will call get_balance first on prepare_sweep_transaction
    @get_balance_response = File.new("spec/test-cases/json/get_balance_response.json").read
    @stub_network = stub_request(:post, "https://block.io/api/v2/get_balance").
                      with(
                        body: {:api_key => @api_key}.to_json,
                        headers: @headers).
                      to_return(status: 200, body: @get_balance_response, headers: {})

  end

  context "p2pkh" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key)
      
      @prepare_sweep_transaction_response_p2pkh = File.new("spec/test-cases/json/prepare_sweep_transaction_response_p2pkh.json").read
      @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_sweep_transaction").
                 with(
                   body: @req_params.merge({:api_key => @api_key}).to_json,
                   headers: @headers).
                 to_return(status: 200, body: @prepare_sweep_transaction_response_p2pkh, headers: {})
      
      @create_and_sign_transaction_response_sweep_p2pkh = File.new("spec/test-cases/json/create_and_sign_transaction_response_sweep_p2pkh.json").read
      
    end
    
    it "success" do

      @blockio.prepare_sweep_transaction(@req_params_with_wif)

      expect(@stub1).to have_been_requested.times(1)

      expect(@blockio.create_and_sign_transaction(Oj.safe_load(@prepare_sweep_transaction_response_p2pkh))).to eq(Oj.safe_load(@create_and_sign_transaction_response_sweep_p2pkh))

    end

  end
  
  context "p2wpkh-over-p2sh" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key)
      
      @prepare_sweep_transaction_response_p2wpkh_over_p2sh = File.new("spec/test-cases/json/prepare_sweep_transaction_response_p2wpkh_over_p2sh.json").read
      @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_sweep_transaction").
                 with(
                   body: @req_params.merge({:api_key => @api_key}).to_json,
                   headers: @headers).
                 to_return(status: 200, body: @prepare_sweep_transaction_response_p2wpkh_over_p2sh, headers: {})
      
      @create_and_sign_transaction_response_sweep_p2wpkh_over_p2sh = File.new("spec/test-cases/json/create_and_sign_transaction_response_sweep_p2wpkh_over_p2sh.json").read
      
    end
    
    it "success" do

      @blockio.prepare_sweep_transaction(@req_params_with_wif)

      expect(@stub1).to have_been_requested.times(1)

      expect(@blockio.create_and_sign_transaction(Oj.safe_load(@prepare_sweep_transaction_response_p2wpkh_over_p2sh))).to eq(Oj.safe_load(@create_and_sign_transaction_response_sweep_p2wpkh_over_p2sh))

    end

  end
  
  context "p2wpkh" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key)
      
      @prepare_sweep_transaction_response_p2wpkh = File.new("spec/test-cases/json/prepare_sweep_transaction_response_p2wpkh.json").read
      @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_sweep_transaction").
                 with(
                   body: @req_params.merge({:api_key => @api_key}).to_json,
                   headers: @headers).
                 to_return(status: 200, body: @prepare_sweep_transaction_response_p2wpkh, headers: {})
      
      @create_and_sign_transaction_response_sweep_p2wpkh = File.new("spec/test-cases/json/create_and_sign_transaction_response_sweep_p2wpkh.json").read
      
    end
    
    it "success" do

      @blockio.prepare_sweep_transaction(@req_params_with_wif)

      expect(@stub1).to have_been_requested.times(1)

      expect(@blockio.create_and_sign_transaction(Oj.safe_load(@prepare_sweep_transaction_response_p2wpkh))).to eq(Oj.safe_load(@create_and_sign_transaction_response_sweep_p2wpkh))

    end

  end
  
end
  
