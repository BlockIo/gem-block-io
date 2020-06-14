require_relative '../lib/block_io'

describe "generate sha256 hash" do
  it "generates a sha256 hash of deadbeef" do
    expect(BlockIo::Helper.sha256("deadbeef")).to eq("2baf1f40105d9501fe319a8ec463fdf4325a2a5df445adf3f572f626253678c9")
  end  
end

describe "generate aes key from pin" do
  it "generates a decryption key from a pin" do
    expect(BlockIo::Helper.pinToAesKey("deadbeef", false)).to eq([["b87ddac3d84865782a0edbc21b5786d56795dd52bab0fe49270b3726372a83fe"].pack("H*")].pack("m0"))
  end
end

describe "encrypt data" do
  it "encrypts beadbeef using deadbeef" do
    encryption_key = BlockIo::Helper.pinToAesKey("deadbeef")
    encrypted_data = BlockIo::Helper.encrypt("beadbeef", encryption_key)
    expect(encrypted_data).to eq("3wIJtPoC8KO6S7x6LtrN0g==")
  end
end

describe "decrypt data" do
  it "decrypts encrypted beadbeef using deadbeef" do
    encryption_key = BlockIo::Helper.pinToAesKey("deadbeef")
    encrypted_data = "3wIJtPoC8KO6S7x6LtrN0g=="
    decrypted_data = BlockIo::Helper.decrypt(encrypted_data, encryption_key)
    expect(decrypted_data).to eq("beadbeef")
  end
end

describe "decrypt data using invalid pin" do
  it "decrypts encrypted beadbeef using beaddeef" do
    encryption_key = BlockIo::Helper.pinToAesKey("beaddeef")
    encrypted_data = "3wIJtPoC8KO6S7x6LtrN0g=="
    expect{BlockIo::Helper.decrypt(encrypted_data, encryption_key)}.to raise_error(Exception, "Invalid Secret PIN provided.")
  end
end
