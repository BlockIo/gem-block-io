
describe "Oj.load_file" do

  context "withdraw_response.json" do

    before(:each) do
      @data = Oj.load_file("spec/data/withdraw_response.json")
    end
    
    it "valid?(data.reference_id)" do
      expect(@data["data"]["reference_id"]).to eq("25cd8b0ad5cf8987c99e16921149cdb0680b1c1360276b4d652904958b19a8bd")
    end

  end

  context "sign_and_finalize_withdraw_request.json" do

    before(:each) do
      @data = Oj.load_file("spec/data/sign_and_finalize_withdrawal_request.json")
    end

    it ".key?(signature_data)" do
      expect(@data.key?("signature_data")).to eq(true)
    end

    it "signature_data.is_a?(String)" do
      expect(@data["signature_data"].is_a?(String)).to eq(true)
    end
    
  end
  
end

describe "Helper.signData" do

  context "bad_key" do

    before(:each) do
      @bad_key = BlockIo::Key.new(nil, false)
      @data = Oj.load_file("spec/data/withdraw_response.json")
      @signatures_added = BlockIo::Helper.signData(@data["data"]["inputs"], [@bad_key])
    end
    
    it "signed_data.nil?" do
      all_signatures_empty = @data["data"]["inputs"].all?{|input| input["signers"].first["signed_data"].nil? }    
      expect(all_signatures_empty).to eq(true)
    end

    it "!signatures_added?" do
      expect(@signatures_added).to eq(false)
    end

  end
  
  context "key" do

    before(:each) do
      @data = Oj.load_file("spec/data/withdraw_response.json") 
      @encryption_key = BlockIo::Helper.pinToAesKey("blockiotestpininsecure")
      @decrypted = BlockIo::Helper.decrypt(@data["data"]["encrypted_passphrase"]["passphrase"], @encryption_key)
      @key = BlockIo::Key.from_passphrase(@decrypted, false)
      @bad_key = BlockIo::Key.new(nil, false)
      @result = Oj.safe_load(Oj.load_file("spec/data/sign_and_finalize_withdrawal_request.json")["signature_data"])["inputs"]
      @signatures_added = BlockIo::Helper.signData(@data["data"]["inputs"], [@key])
    end
    
    it "signatures_added?" do
      expect(@signatures_added).to eq(true)
    end
    
    it "valid_signature?(key)" do
      all_signatures_valid = @data["data"]["inputs"].all?{|input| @key.valid_signature?(input["signers"].first["signed_data"], input["data_to_sign"]) }
      expect(all_signatures_valid).to eq(true)
    end

    it "result.eq?(expected_signed_data)" do
      matches_signed_data = Oj.dump(@result).eql?(Oj.dump(@data["data"]["inputs"]))
      expect(matches_signed_data).to eq(true)
    end

    it "valid_signature?(bad_key)" do
      all_signatures_invalid = @data["data"]["inputs"].all?{|input|
        (!input["signers"].first["signed_data"].nil? and
         !@bad_key.valid_signature?(input["signers"].first["signed_data"], input["data_to_sign"]))
      }
      expect(all_signatures_invalid).to eq(true)    
    end

  end
end
