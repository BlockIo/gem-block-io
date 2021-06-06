
describe "Helper.sha256" do
  it "deadbeef" do
    expect(BlockIo::Helper.sha256("deadbeef")).to eq("2baf1f40105d9501fe319a8ec463fdf4325a2a5df445adf3f572f626253678c9")
  end  
end

describe "Helper.pinToAesKey" do
  describe "no_salt" do
    it "deadbeef" do
      expect(BlockIo::Helper.pinToAesKey("deadbeef")).to eq([["b87ddac3d84865782a0edbc21b5786d56795dd52bab0fe49270b3726372a83fe"].pack("H*")].pack("m0"))
    end
  end
  describe "salt" do
    it "922445847c173e90667a19d90729e1fb" do
      expect(BlockIo::Helper.pinToAesKey("deadbeef", 500000, "922445847c173e90667a19d90729e1fb")).to eq([["f206403c6bad20e1c8cb1f3318e17cec5b2da0560ed6c7b26826867452534172"].pack("H*")].pack("m0"))
    end
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

describe "Helper.encrypt_aes256cbc" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef", 500000, "922445847c173e90667a19d90729e1fb")
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key, "11bc22166c8cf8560e5fa7e5c622bb0f", "AES-256-CBC")
  end

  it "beadbeef" do
    expect(@encrypted_data).to eq("LExu1rUAtIBOekslc328Lw==")
  end

end

describe "Helper.decrypt_aes256cbc" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef", 500000, "922445847c173e90667a19d90729e1fb")
    @bad_encryption_key = BlockIo::Helper.pinToAesKey(SecureRandom.hex(8))
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key, "11bc22166c8cf8560e5fa7e5c622bb0f", "AES-256-CBC")
  end

  it "encryption_key" do
    @decrypted_data = BlockIo::Helper.decrypt(@encrypted_data, @encryption_key, "11bc22166c8cf8560e5fa7e5c622bb0f", "AES-256-CBC")
    expect(@decrypted_data).to eq("beadbeef")
  end

  it "bad_encryption_key" do
    expect{
      BlockIo::Helper.decrypt(@encrypted_data, @bad_encryption_key, "11bc22166c8cf8560e5fa7e5c622bb0f", "AES-256-CBC")
    }.to raise_error(Exception, "Invalid Secret PIN provided.")
  end
  
end

describe "Helper.dynamicExtractKey" do

  before(:each) do
    @user_key = Oj.safe_load('{"encrypted_passphrase":"LExu1rUAtIBOekslc328Lw==","public_key":"02f87f787bffb30396984cb6b3a9d6830f32d5b656b3e39b0abe4f3b3c35d99323","algorithm":{"pbkdf2_salt":"922445847c173e90667a19d90729e1fb","pbkdf2_iterations":500000,"pbkdf2_hash_function":"SHA256","pbkdf2_phase1_key_length":16,"pbkdf2_phase2_key_length":32,"aes_iv":"11bc22166c8cf8560e5fa7e5c622bb0f","aes_cipher":"AES-256-CBC"}}')
    @pin = "deadbeef"
  end

  it "success" do
    expect(BlockIo::Helper.dynamicExtractKey(@user_key, @pin).public_key_hex).to eq(BlockIo::Key.from_passphrase("beadbeef").public_key_hex)
  end
  
end
