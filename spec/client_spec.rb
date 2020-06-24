
describe "Client.withdraw" do

  before(:each) do

    @api_key = "0000-0000-0000-0000"
    @req_params = {:from_labels => "testDest", :amounts => "100", :to_labels => "default"}
    @headers = {
      'Accept' => 'application/json',
      'Connection' => 'Keep-Alive',
      'Content-Type' => 'application/json; charset=UTF-8',
      'Host' => 'block.io',
      'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
    }
    
    @withdraw_response = File.new("spec/data/withdraw_response.json", "r").read
    @stub1 = stub_request(:post, "https://block.io/api/v2/withdraw").
               with(
                 body: @req_params.merge({:api_key => @api_key}).to_json,
                 headers: @headers
               ).
               to_return(status: 200, body: @withdraw_response, headers: {})
    
    @sign_and_finalize_withdrawal_request = Oj.dump(Oj.load_file("spec/data/sign_and_finalize_withdrawal_request.json"))
    @success_response = Oj.dump({"status" => "success", "data" => {"network" => "random", "txid" => "random"}})
    @stub2 = stub_request(:post, "https://block.io/api/v2/sign_and_finalize_withdrawal").
               with(
                 body: @sign_and_finalize_withdrawal_request,
                 headers: @headers
               ).to_return(status: 200, body: @success_response, headers: {})

  end
  
  context "pin" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => "blockiotestpininsecure", :version => 2)

    end
    
    it "success" do

      @blockio.withdraw(@req_params)

      expect(@stub1).to have_been_requested.times(1)
      expect(@stub2).to have_been_requested.times(1)

    end
    
  end
  
  context "key" do

    before(:each) do

      @encryption_key = BlockIo::Helper.pinToAesKey("blockiotestpininsecure")
      @key = BlockIo::Helper.extractKey(Oj.load(@withdraw_response)["data"]["encrypted_passphrase"]["passphrase"], @encryption_key)

      @blockio = BlockIo::Client.new(:api_key => @api_key, :keys => [@key], :version => 2)

    end
    
    it "success" do

      @blockio.withdraw(@req_params)

      expect(@stub1).to have_been_requested.times(1)
      expect(@stub2).to have_been_requested.times(1)

    end
    
  end
  
end

describe "Client.sweep" do

  before(:each) do

    @api_key = "0000-0000-0000-0000"
    @wif = "cTYLVcC17cYYoRjaBu15rEcD5WuDyowAw562q2F1ihcaomRJENu5"
    @key = BlockIo::Key.from_wif(@wif)
    @req_params = {:to_address => "QhSWVppS12Fqv6dh3rAyoB18jXh5mB1hoC", :from_address => "tltc1qpygwklc39wl9p0wvlm0p6x42sh9259xdjl059s", :public_key => @key.public_key}
    @headers = {
      'Accept' => 'application/json',
      'Connection' => 'Keep-Alive',
      'Content-Type' => 'application/json; charset=UTF-8',
      'Host' => 'block.io',
      'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
    }

    @sweep_from_address_response = File.new("spec/data/sweep_from_address_response.json", "r").read
    @stub1 = stub_request(:post, "https://block.io/api/v2/sweep_from_address").
               with(
                 body: @req_params.merge({:api_key => @api_key}).to_json,
                 headers: @headers
               ).
               to_return(status: 200, body: @sweep_from_address_response, headers:{})

    @sign_and_finalize_sweep_request = Oj.dump(Oj.load_file("spec/data/sign_and_finalize_sweep_request.json"))
    @success_response = Oj.dump({"status" => "success", "data" => {"network" => "random", "txid" => "random"}})
    @stub2 = stub_request(:post, "https://block.io/api/v2/sign_and_finalize_sweep").
               with(
                 body: @sign_and_finalize_sweep_request,
                 headers: @headers
               ).to_return(status: 200, body: @success_response, headers: {})

  end
  
  context "key" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :version => 2)

    end
    
    it "success" do

      @blockio.sweep_from_address(:to_address => @req_params[:to_address], :from_address => @req_params[:from_address], :private_key => @wif)

      expect(@stub1).to have_been_requested.times(1)
      expect(@stub2).to have_been_requested.times(1)

    end
    
  end
  
end

describe "Client.withdraw_from_dtrust_address" do

  before(:each) do

    @api_key = "0000-0000-0000-0000"
    @req_params = {:from_address => "tltc1q8y9naxlsw7xay4jesqshnpeuc0ap8fg9ejm2j2memwq4ng87dk3s88nr5j", :to_addresses => "QhSWVppS12Fqv6dh3rAyoB18jXh5mB1hoC", :amounts => "0.09"}
    @headers = {
      'Accept' => 'application/json',
      'Connection' => 'Keep-Alive',
      'Content-Type' => 'application/json; charset=UTF-8',
      'Host' => 'block.io',
      'User-Agent' => "gem:block_io:#{BlockIo::VERSION}"
    }

    @keys = [
      BlockIo::Key.new("b515fd806a662e061b488e78e5d0c2ff46df80083a79818e166300666385c0a2"), # alpha1alpha2alpha3alpha4
      BlockIo::Key.new("1584b821c62ecdc554e185222591720d6fe651ed1b820d83f92cdc45c5e21f"), # alpha2alpha3alpha4alpha1
      BlockIo::Key.new("2f9090b8aa4ddb32c3b0b8371db1b50e19084c720c30db1d6bb9fcd3a0f78e61"), # alpha3alpha4alpha1alpha2
      BlockIo::Key.new("6c1cefdfd9187b36b36c3698c1362642083dcc1941dc76d751481d3aa29ca65") # alpha4alpha1alpha2alpha3
    ].freeze
    
    @withdraw_from_dtrust_address_response = File.new("spec/data/withdraw_from_dtrust_address_response.json", "r").read
    @stub1 = stub_request(:post, "https://block.io/api/v2/withdraw_from_dtrust_address").
               with(
                 body: @req_params.merge({:api_key => @api_key}).to_json,
                 headers: @headers
               ).
               to_return(status: 200, body: @withdraw_from_dtrust_address_response, headers: {})
    
    @sign_and_finalize_dtrust_withdrawal_request = Oj.dump(Oj.load_file("spec/data/sign_and_finalize_dtrust_withdrawal_request.json"))
    @success_response = Oj.dump({"status" => "success", "data" => {"network" => "random", "txid" => "random"}})
    @stub2 = stub_request(:post, "https://block.io/api/v2/sign_and_finalize_withdrawal").
               with(
                 body: @sign_and_finalize_dtrust_withdrawal_request,
                 headers: @headers
               ).to_return(status: 200, body: @success_response, headers: {})

  end
  
  context "without_keys_at_init" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :version => 2)

    end

    it "only_required_signatures" do
      
      @response = @blockio.withdraw_from_dtrust_address(@req_params)

      BlockIo::Helper.signData(@response["data"]["inputs"], @keys)
      only_required_signatures = @response["data"]["inputs"].map{|input| input["signers"].map{|s| (s["signed_data"].nil? ? 0 : 1)}.inject(:+) == input["signatures_needed"]}.all?{|x| x}
      
      expect(@stub1).to have_been_requested.times(1)
      expect(only_required_signatures).to eq(true)
      
    end

    it "success" do

      @response = @blockio.withdraw_from_dtrust_address(@req_params)

      BlockIo::Helper.signData(@response["data"]["inputs"], @keys)
      
      @blockio.sign_and_finalize_withdrawal({:signature_data => @response["data"]})
      
      expect(@stub1).to have_been_requested.times(1)
      expect(@stub2).to have_been_requested.times(1)

    end
    
  end

  context "with_keys_at_init" do

    before(:each) do
      @blockio = BlockIo::Client.new(:api_key => @api_key, :keys => @keys, :version => 2)
    end
    
    it "success" do

      @blockio.withdraw_from_dtrust_address(@req_params)
      
      expect(@stub1).to have_been_requested.times(1)
      expect(@stub2).to have_been_requested.times(1)

    end
    
  end
  
end
