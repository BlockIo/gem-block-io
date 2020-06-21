
describe "Client.withdraw" do

  context "any" do

    before(:each) do

      @api_key = "1f7d08a6-3f91-404c-b7c4-f3f1c12c3b16"
      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => "blockiotestpininsecure", :version => 2)
      @withdraw_response = File.new("spec/data/withdraw_response.json", "r").read
      @sign_and_finalize_withdrawal_request = Oj.dump(Oj.load_file("spec/data/sign_and_finalize_withdrawal_request.json"))
      @req_params = {:from_labels => "testDest", :amounts => "100", :to_labels => "default"}
      @headers = {
        'Accept' => 'application/json',
        'Connection' => 'close',
        'Content-Type' => 'application/json; charset=UTF-8',
        'Host' => 'block.io',
        'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
      }

    end
    
    it "success" do

      @success_response = Oj.dump({"status" => "success", "data" => {"network" => "random", "txid" => "random"}})

      @stub1 = stub_request(:post, "https://block.io/api/v2/withdraw").
                with(
                  body: @req_params.merge({:api_key => @api_key}).to_json,
                  headers: @headers
                ).
                to_return(status: 200, body: @withdraw_response, headers: {})
      
      @stub2 = stub_request(:post, "https://block.io/api/v2/sign_and_finalize_withdrawal").
                with(
                  body: @sign_and_finalize_withdrawal_request,
                  headers: @headers
                ).to_return(status: 200, body: @success_response, headers: {})
      
      @blockio.withdraw(@req_params)

      expect(@stub1).to have_been_requested.times(1)
      expect(@stub2).to have_been_requested.times(1)

    end
    
  end
  
end
