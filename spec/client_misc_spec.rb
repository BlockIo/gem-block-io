require 'securerandom'

describe "Client" do

  before(:each) do
    @api_key = "0000-0000-0000-0000"
    @req_params = {:to_address => "QTLcyTFrH7T6kqUsi1VV2mJVXmX3AmwUNH", :amounts => "0.248"}
    
    @prepare_transaction_response = File.new("spec/test-cases/json/prepare_transaction_response_with_blockio_fee_and_expected_unsigned_txid.json").read
    @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_transaction").
               with(
                 body: @req_params.merge({:api_key => @api_key}).to_json,
                 headers: SPEC_REQUEST_HEADERS).
               to_return(status: 200, body: @prepare_transaction_response, headers: {})

    @create_and_sign_transaction_response = File.new("spec/test-cases/json/create_and_sign_transaction_response_with_blockio_fee_and_expected_unsigned_txid.json").read
    @summarize_prepared_transaction_response = File.new("spec/test-cases/json/summarize_prepared_transaction_response_with_blockio_fee_and_expected_unsigned_txid.json").read
    
    @insecure_pin_valid = "d1650160bd8d2bb32bebd139d0063eb6063ffa2f9e4501ad" # still insecure, don't use this!
    @insecure_pin_invalid = "blockiotestpininsecure"
  end

  context "summarize_prepare_transaction" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end
    
    it "success" do

      @blockio.prepare_transaction(@req_params)

      expect(@stub1).to have_been_requested.times(1)

      expect(@blockio.summarize_prepared_transaction(Oj.safe_load(@prepare_transaction_response))).to eq(Oj.safe_load(@summarize_prepared_transaction_response))
      
      expect(@blockio.create_and_sign_transaction(Oj.safe_load(@prepare_transaction_response))).to eq(Oj.safe_load(@create_and_sign_transaction_response))

    end

  end
  
  context "create_and_sign_transaction_with_invalid_expected_unsigned_txid" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end
    
    it "fails" do

      @blockio.prepare_transaction(@req_params)

      expect(@stub1).to have_been_requested.times(1)

      @bad_response = Oj.safe_load(@prepare_transaction_response)
      @bad_response['data']['expected_unsigned_txid'] = SecureRandom.hex(32)
      
      expect{@blockio.create_and_sign_transaction(@bad_response)}.to raise_error(Exception, "Expected unsigned transaction ID mismatch. Please report this error to support@block.io.")

    end

  end
  
end
  
