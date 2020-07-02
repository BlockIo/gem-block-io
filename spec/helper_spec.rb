
describe "Helper.sha256" do
  it "deadbeef" do
    expect(BlockIo::Helper.sha256("deadbeef")).to eq("2baf1f40105d9501fe319a8ec463fdf4325a2a5df445adf3f572f626253678c9")
  end  
end

describe "Helper.pinToAesKey" do
  it "deadbeef" do
    expect(BlockIo::Helper.pinToAesKey("deadbeef", false)).to eq([["b87ddac3d84865782a0edbc21b5786d56795dd52bab0fe49270b3726372a83fe"].pack("H*")].pack("m0"))
  end
end

describe "Helper.encrypt" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef")
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key)
  end

  it "beadbeef" do
    expect(@encrypted_data).to eq("3wIJtPoC8KO6S7x6LtrN0g==")
  end

end

describe "Helper.decrypt" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef")
    @bad_encryption_key = BlockIo::Helper.pinToAesKey(SecureRandom.hex(8))
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key)
  end

  it "encryption_key" do
    @decrypted_data = BlockIo::Helper.decrypt(@encrypted_data, @encryption_key)
    expect(@decrypted_data).to eq("beadbeef")
  end

  it "bad_encryption_key" do
    expect{
      BlockIo::Helper.decrypt(@encrypted_data, @bad_encryption_key)
    }.to raise_error(Exception, "Invalid Secret PIN provided.")
  end
  
end
