describe "Client.create_and_sign_transaction" do

  before(:each) do
    @api_key = "0000-0000-0000-0000"
    @insecure_pin_valid = "d1650160bd8d2bb32bebd139d0063eb6063ffa2f9e4501ad" # still insecure, don't use this!
    @private_keys = ["b515fd806a662e061b488e78e5d0c2ff46df80083a79818e166300666385c0a2",
                     "1584b821c62ecdc554e185222591720d6fe651ed1b820d83f92cdc45c5e21f",
                     "2f9090b8aa4ddb32c3b0b8371db1b50e19084c720c30db1d6bb9fcd3a0f78e61",
                     "6c1cefdfd9187b36b36c3698c1362642083dcc1941dc76d751481d3aa29ca65"]
  end

  context "dtrust_p2sh_3of5_keys" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_195_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2SH_3of5_195inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2SH_3of5_195inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

  end
  

  context "dtrust_p2sh_4of5_keys" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_195_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2SH_4of5_195inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2SH_4of5_195inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

  end
  

  context "dtrust_p2wsh_over_p2sh_3of5_keys" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_251_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2WSH-over-P2SH_3of5_251inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2WSH-over-P2SH_3of5_251inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_252_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2WSH-over-P2SH_3of5_252inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2WSH-over-P2SH_3of5_252inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_253_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2WSH-over-P2SH_3of5_253inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2WSH-over-P2SH_3of5_253inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

  end
  
  context "dtrust_p2wsh_over_p2sh_4of5_keys" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_251_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2WSH-over-P2SH_4of5_251inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2WSH-over-P2SH_4of5_251inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_252_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2WSH-over-P2SH_4of5_252inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2WSH-over-P2SH_4of5_252inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_253_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_P2WSH-over-P2SH_4of5_253inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_P2WSH-over-P2SH_4of5_253inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

  end

  ####
  
  context "dtrust_witness_v0_3of5_keys" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_251_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_WITNESS_V0_3of5_251inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_WITNESS_V0_3of5_251inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_252_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_WITNESS_V0_3of5_252inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_WITNESS_V0_3of5_252inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_253_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_WITNESS_V0_3of5_253inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_WITNESS_V0_3of5_253inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_251_outputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0_3of5_251outputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_3of5_251outputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_252_outputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0_3of5_252outputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_3of5_252outputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_253_outputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0_3of5_253outputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_3of5_253outputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(3))
      
      expect(actual_response).to eq(expected_response)
      
    end

  end
  
  context "dtrust_witness_v0_4of5_keys" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_251_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_WITNESS_V0_4of5_251inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_WITNESS_V0_4of5_251inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_252_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_WITNESS_V0_4of5_252inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_WITNESS_V0_4of5_252inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_253_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_WITNESS_V0_4of5_253inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_WITNESS_V0_4of5_253inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_251_outputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0_4of5_251outputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_4of5_251outputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_252_outputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0_4of5_252outputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_4of5_252outputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

    it "succeeds_on_253_outputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_dtrust_transaction_response_witness_v0_4of5_253outputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_dtrust_witness_v0_4of5_253outputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request, @private_keys.first(4))
      
      expect(actual_response).to eq(expected_response)
      
    end

  end
  
  context "p2wsh_over_p2sh_1of2" do

    before(:each) do

      @blockio = BlockIo::Client.new(:api_key => @api_key, :pin => @insecure_pin_valid)
      
    end

    it "succeeds_on_251_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_transaction_response_P2WSH-over-P2SH_1of2_251inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_P2WSH-over-P2SH_1of2_251inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request)
      
      expect(actual_response).to eq(expected_response)
      
    end
    
    it "succeeds_on_252_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_transaction_response_P2WSH-over-P2SH_1of2_252inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_P2WSH-over-P2SH_1of2_252inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request)
      
      expect(actual_response).to eq(expected_response)
      
    end
    
    it "succeeds_on_253_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_transaction_response_P2WSH-over-P2SH_1of2_253inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_P2WSH-over-P2SH_1of2_253inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request)
      
      expect(actual_response).to eq(expected_response)
      
    end
    
    it "succeeds_on_762_inputs" do
    
      request = Oj.safe_load(File.open("spec/test-cases/json/prepare_transaction_response_P2WSH-over-P2SH_1of2_762inputs.json").read)
      expected_response = Oj.safe_load(File.open("spec/test-cases/json/create_and_sign_transaction_response_P2WSH-over-P2SH_1of2_762inputs.json").read)
      
      actual_response = @blockio.create_and_sign_transaction(request)
      
      expect(actual_response).to eq(expected_response)
      
    end
    
  end
  
end
  
