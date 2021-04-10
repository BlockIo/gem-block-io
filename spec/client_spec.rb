describe "Client.prepare_transaction" do

  before(:each) do
    @api_key = "0000-0000-0000-0000"
    @req_params = {:to_address => "QTLcyTFrH7T6kqUsi1VV2mJVXmX3AmwUNH", :amounts => "0.248"}
    @headers = {
      'Accept' => 'application/json',
      'Connection' => 'Keep-Alive',
      'Content-Type' => 'application/json; charset=UTF-8',
      'Host' => 'block.io',
      'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
    }
    
    @prepare_transaction_response = File.new("spec/test-cases/json/prepare_transaction_response.json").read
    @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_transaction").
               with(
                 body: @req_params.merge({:api_key => @api_key}).to_json,
                 headers: @headers).
               to_return(status: 200, body: @prepare_transaction_response, headers: {})

    @create_and_sign_transaction_response = File.new("spec/test-cases/json/create_and_sign_transaction_response.json").read
    
    @insecure_pin_valid = "d1650160bd8d2bb32bebd139d0063eb6063ffa2f9e4501ad" # still insecure, don't use this!
    @insecure_pin_invalid = "blockiotestpininsecure"
  end

  context "pin_valid" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end
    
    it "success" do

      @blockio.prepare_transaction(@req_params)

      expect(@stub1).to have_been_requested.times(1)

      expect(@blockio.create_and_sign_transaction(Oj.load(@prepare_transaction_response))).to eq(Oj.load(@create_and_sign_transaction_response))

    end

  end
  
  context "pin_invalid" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_invalid)
      
    end
    
    it "fails" do

      @blockio.prepare_transaction(@req_params)

      expect(@stub1).to have_been_requested.times(1)

      expect { @blockio.create_and_sign_transaction(Oj.load(@prepare_transaction_response)) }.to raise_error(Exception, "Invalid Secret PIN provided.")
      
    end

  end

end
  
