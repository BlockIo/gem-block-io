describe "Client.prepare_dtrust_transaction" do

  before(:each) do
    @api_key = "0000-0000-0000-0000"
    @private_keys = ["b515fd806a662e061b488e78e5d0c2ff46df80083a79818e166300666385c0a2",
                     "1584b821c62ecdc554e185222591720d6fe651ed1b820d83f92cdc45c5e21f",
                     "2f9090b8aa4ddb32c3b0b8371db1b50e19084c720c30db1d6bb9fcd3a0f78e61",
                     "6c1cefdfd9187b36b36c3698c1362642083dcc1941dc76d751481d3aa29ca65"]
    @to_address = "QcnYiN3t3foHxHv7CnqXrmRoiMkADhapZw"
    @amount = "0.00020000"
    @headers = {
      'Accept' => 'application/json',
      'Connection' => 'Keep-Alive',
      'Content-Type' => 'application/json; charset=UTF-8',
      'Host' => 'block.io',
      'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
    }

  end

  context "p2sh" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key)
      @from_address = "QZVSzPeaEJxB9bYuDEL7iWrHSdGbAP3pXV"
      @prepare_dtrust_transaction_response_p2sh = File.new("spec/test-cases/json/prepare_dtrust_transaction_response_p2sh.json").read
      @req_params = {:from_address => @from_address, :amount => @amount, :to_address => @to_address}
      @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_dtrust_transaction").
                 with(
                   body: @req_params.merge({:api_key => @api_key}).to_json,
                   headers: @headers).
                 to_return(status: 200, body: @prepare_dtrust_transaction_response_p2sh, headers: {})
      
      @create_and_sign_transaction_response_dtrust_p2sh_3_of_5_keys = File.new("spec/test-cases/json/create_and_sign_transaction_response_dtrust_p2sh_3_of_5_keys.json").read
      @create_and_sign_transaction_response_dtrust_p2sh_4_of_5_keys = File.new("spec/test-cases/json/create_and_sign_transaction_response_dtrust_p2sh_4_of_5_keys.json").read
      
    end

    context "3_of_5_keys" do
      it "success" do
        
        @blockio.prepare_dtrust_transaction(@req_params)
        
        expect(@stub1).to have_been_requested.times(1)
        
        expect(
          @blockio.create_and_sign_transaction(Oj.load(@prepare_dtrust_transaction_response_p2sh), @private_keys.first(3))
        ).to eq(Oj.load(@create_and_sign_transaction_response_dtrust_p2sh_3_of_5_keys))

      end
    end

    context "4_of_5_keys" do
      it "success" do

        @blockio.prepare_dtrust_transaction(@req_params)
        
        expect(@stub1).to have_been_requested.times(1)
        
        expect(@blockio.create_and_sign_transaction(Oj.load(@prepare_dtrust_transaction_response_p2sh), @private_keys)).to eq(Oj.load(@create_and_sign_transaction_response_dtrust_p2sh_4_of_5_keys))

      end
    end
    
  end
  
  context "p2wsh_over_p2sh" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key)
      @from_address = "Qg1QzgjUDkwaHeT7Yznuyu2V1keJieDVAF"
      @prepare_dtrust_transaction_response_p2wsh_over_p2sh = File.new("spec/test-cases/json/prepare_dtrust_transaction_response_p2wsh_over_p2sh.json").read
      @req_params = {:from_address => @from_address, :amount => @amount, :to_address => @to_address}
      @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_dtrust_transaction").
                 with(
                   body: @req_params.merge({:api_key => @api_key}).to_json,
                   headers: @headers).
                 to_return(status: 200, body: @prepare_dtrust_transaction_response_p2wsh_over_p2sh, headers: {})
      
      @create_and_sign_transaction_response_dtrust_p2wsh_over_p2sh_3_of_5_keys = File.new("spec/test-cases/json/create_and_sign_transaction_response_dtrust_p2wsh_over_p2sh_3_of_5_keys.json").read
      @create_and_sign_transaction_response_dtrust_p2wsh_over_p2sh_4_of_5_keys = File.new("spec/test-cases/json/create_and_sign_transaction_response_dtrust_p2wsh_over_p2sh_4_of_5_keys.json").read
      
    end

    context "3_of_5_keys" do
      it "success" do
        
        @blockio.prepare_dtrust_transaction(@req_params)
        
        expect(@stub1).to have_been_requested.times(1)
        
        expect(
          @blockio.create_and_sign_transaction(Oj.load(@prepare_dtrust_transaction_response_p2wsh_over_p2sh), @private_keys.first(3))
        ).to eq(Oj.load(@create_and_sign_transaction_response_dtrust_p2wsh_over_p2sh_3_of_5_keys))

      end
    end

    context "4_of_5_keys" do
      it "success" do

        @blockio.prepare_dtrust_transaction(@req_params)
        
        expect(@stub1).to have_been_requested.times(1)
        
        expect(
          @blockio.create_and_sign_transaction(Oj.load(@prepare_dtrust_transaction_response_p2wsh_over_p2sh), @private_keys)
        ).to eq(Oj.load(@create_and_sign_transaction_response_dtrust_p2wsh_over_p2sh_4_of_5_keys))

      end
    end
    
  end
  
  context "witness_v0" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key)
      @from_address = "tltc1qtvscupcwnlsykujp98y0jhf8s4x48mzrr3v8v822ytg6vmprvzaqj8jd0h"
      @prepare_dtrust_transaction_response_witness_v0 = File.new("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0.json").read
      @req_params = {:from_address => @from_address, :amount => @amount, :to_address => @to_address}
      @stub1 = stub_request(:post, "https://block.io/api/v2/prepare_dtrust_transaction").
                 with(
                   body: @req_params.merge({:api_key => @api_key}).to_json,
                   headers: @headers).
                 to_return(status: 200, body: @prepare_dtrust_transaction_response_witness_v0, headers: {})
      
      @create_and_sign_transaction_response_dtrust_witness_v0_3_of_5_keys = File.new("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_3_of_5_keys.json").read
      @create_and_sign_transaction_response_dtrust_witness_v0_4_of_5_keys = File.new("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_4_of_5_keys.json").read
      
    end

    context "3_of_5_keys" do
      it "success" do
        
        @blockio.prepare_dtrust_transaction(@req_params)
        
        expect(@stub1).to have_been_requested.times(1)
        
        expect(
          @blockio.create_and_sign_transaction(Oj.load(@prepare_dtrust_transaction_response_witness_v0), @private_keys.first(3))
        ).to eq(Oj.load(@create_and_sign_transaction_response_dtrust_witness_v0_3_of_5_keys))

      end
    end

    context "4_of_5_keys" do
      it "success" do

        @blockio.prepare_dtrust_transaction(@req_params)
        
        expect(@stub1).to have_been_requested.times(1)
        
        expect(
          @blockio.create_and_sign_transaction(Oj.load(@prepare_dtrust_transaction_response_witness_v0), @private_keys)
        ).to eq(Oj.load(@create_and_sign_transaction_response_dtrust_witness_v0_4_of_5_keys))

      end
    end
    
  end
  
end
  
