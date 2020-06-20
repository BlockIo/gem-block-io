require_relative '../lib/block_io'

data = nil

describe "load json object" do
  it "loads a json object from file" do
    data = Oj.load_file("spec/data/withdraw_response.json")
    expect(data["data"]["reference_id"]).to eq("25cd8b0ad5cf8987c99e16921149cdb0680b1c1360276b4d652904958b19a8bd")
  end
end

describe "sign withdraw response" do
  it "with valid key" do

    data = Oj.load_file("spec/data/withdraw_response.json")
    encryption_key = BlockIo::Helper.pinToAesKey("blockiotestpininsecure")
    decrypted = BlockIo::Helper.decrypt(data["data"]["encrypted_passphrase"]["passphrase"], encryption_key)
    key = BlockIo::Key.from_passphrase(decrypted)

    BlockIo::Helper.signData(data["data"]["inputs"], [key])

    all_signatures_valid = data["data"]["inputs"].all?{|input| key.valid_signature?(input["signers"].first["signed_data"], input["data_to_sign"]) }
    
    expect(all_signatures_valid).to eq(true)

    bad_key = BlockIo::Key.new
    all_signatures_invalid = data["data"]["inputs"].all?{|input| !bad_key.valid_signature?(input["signers"].first["signed_data"], input["data_to_sign"]) }

    expect(all_signatures_invalid).to eq(true)
    
  end
end

describe "sign withdraw response with valid key" do
  it "and verify with invalid key" do

    data = Oj.load_file("spec/data/withdraw_response.json")
    encryption_key = BlockIo::Helper.pinToAesKey("blockiotestpininsecure")
    decrypted = BlockIo::Helper.decrypt(data["data"]["encrypted_passphrase"]["passphrase"], encryption_key)
    key = BlockIo::Key.from_passphrase(decrypted)

    BlockIo::Helper.signData(data["data"]["inputs"], [key])

    bad_key = BlockIo::Key.new
    all_signatures_invalid = data["data"]["inputs"].all?{|input| !bad_key.valid_signature?(input["signers"].first["signed_data"], input["data_to_sign"]) }

    expect(all_signatures_invalid).to eq(true)
    
  end
end

describe "sign withdraw response" do
  it "with invalid key" do

    data = Oj.load_file("spec/data/withdraw_response.json")
    key = BlockIo::Key.new

    BlockIo::Helper.signData(data["data"]["inputs"], [key])

    all_signatures_empty = data["data"]["inputs"].all?{|input| input["signers"].first["signed_data"].nil? }
    
    expect(all_signatures_empty).to eq(true)

  end
end
