
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
    expect(@encrypted_data[:aes_cipher_text]).to eq("3wIJtPoC8KO6S7x6LtrN0g==")
  end

end

describe "Helper.decrypt" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef")
    @bad_encryption_key = BlockIo::Helper.pinToAesKey(SecureRandom.hex(8))
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key)
  end

  it "encryption_key" do
    @decrypted_data = BlockIo::Helper.decrypt(@encrypted_data[:aes_cipher_text], @encryption_key)
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
    expect(@encrypted_data[:aes_cipher_text]).to eq("LExu1rUAtIBOekslc328Lw==")
  end

end

describe "Helper.decrypt_aes256cbc" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef", 500000, "922445847c173e90667a19d90729e1fb")
    @bad_encryption_key = BlockIo::Helper.pinToAesKey(SecureRandom.hex(8))
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key, "11bc22166c8cf8560e5fa7e5c622bb0f", "AES-256-CBC")
  end

  it "encryption_key" do
    @decrypted_data = BlockIo::Helper.decrypt(@encrypted_data[:aes_cipher_text], @encryption_key, @encrypted_data[:aes_iv], @encrypted_data[:aes_cipher])
    expect(@decrypted_data).to eq("beadbeef")
  end

  it "bad_encryption_key" do
    expect{
      BlockIo::Helper.decrypt(@encrypted_data[:aes_cipher_text], @bad_encryption_key, @encrypted_data[:aes_iv], @encrypted_data[:aes_cipher])
    }.to raise_error(Exception, "Invalid Secret PIN provided.")
  end
  
end

describe "Helper.decrypt_aes256gcm" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef", 500000, "922445847c173e90667a19d90729e1fb")
    @bad_encryption_key = BlockIo::Helper.pinToAesKey(SecureRandom.hex(8))
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key, "a57414b88b67f977829cbdca", "AES-256-GCM", "")
  end

  it "encryption_key" do
    @decrypted_data = BlockIo::Helper.decrypt(@encrypted_data[:aes_cipher_text],
                                              @encryption_key, @encrypted_data[:aes_iv],
                                              @encrypted_data[:aes_cipher],
                                              @encrypted_data[:aes_auth_tag],
                                              @encrypted_data[:aes_auth_data])
    expect(@decrypted_data).to eq("beadbeef")
  end

  it "encryption_key_bad_auth_tag" do
    expect{
      BlockIo::Helper.decrypt(@encrypted_data[:aes_cipher_text],
                              @encryption_key, @encrypted_data[:aes_iv],
                              @encrypted_data[:aes_cipher],
                              @encrypted_data[:aes_auth_tag][0..30],
                              @encrypted_data[:aes_auth_data])
    }.to raise_error(Exception, "Auth tag must be 16 bytes exactly.")
  end

  it "bad_encryption_key" do
    expect{
      BlockIo::Helper.decrypt(@encrypted_data[:aes_cipher_text], @bad_encryption_key, @encrypted_data[:aes_iv], @encrypted_data[:aes_cipher], @encrypted_data[:aes_auth_tag],
                              @encrypted_data[:aes_auth_data])
    }.to raise_error(Exception, "Invalid Secret PIN provided.")
  end
  
end

describe "Helper.encrypt_aes256gcm" do
  before(:each) do
    @encryption_key = BlockIo::Helper.pinToAesKey("deadbeef", 500000, "922445847c173e90667a19d90729e1fb")
    @encrypted_data = BlockIo::Helper.encrypt("beadbeef", @encryption_key, "a57414b88b67f977829cbdca", "AES-256-GCM", "")
  end

  it "beadbeef" do
    expect(@encrypted_data[:aes_cipher_text]).to eq("ELV56Z57KoA=")
    expect(@encrypted_data[:aes_auth_tag]).to eq("adeb7dfe53027bdda5824dc524d5e55a")
  end

end

describe "Helper.dynamicExtractKey" do

  before(:each) do
    @aes256cbc_user_key = Oj.safe_load('{"encrypted_passphrase":"LExu1rUAtIBOekslc328Lw==","public_key":"02f87f787bffb30396984cb6b3a9d6830f32d5b656b3e39b0abe4f3b3c35d99323","algorithm":{"pbkdf2_salt":"922445847c173e90667a19d90729e1fb","pbkdf2_iterations":500000,"pbkdf2_hash_function":"SHA256","pbkdf2_phase1_key_length":16,"pbkdf2_phase2_key_length":32,"aes_iv":"11bc22166c8cf8560e5fa7e5c622bb0f","aes_cipher":"AES-256-CBC","aes_auth_tag":null,"aes_auth_data":null}}')
    @aes256gcm_user_key = Oj.safe_load('{"encrypted_passphrase":"ELV56Z57KoA=","public_key":"02f87f787bffb30396984cb6b3a9d6830f32d5b656b3e39b0abe4f3b3c35d99323","algorithm":{"pbkdf2_salt":"922445847c173e90667a19d90729e1fb","pbkdf2_iterations":500000,"pbkdf2_hash_function":"SHA256","pbkdf2_phase1_key_length":16,"pbkdf2_phase2_key_length":32,"aes_iv":"a57414b88b67f977829cbdca","aes_cipher":"AES-256-GCM","aes_auth_tag":"adeb7dfe53027bdda5824dc524d5e55a","aes_auth_data":""}}')
    @aes256ecb_user_key = Oj.safe_load('{"encrypted_passphrase":"3wIJtPoC8KO6S7x6LtrN0g==","public_key":"02f87f787bffb30396984cb6b3a9d6830f32d5b656b3e39b0abe4f3b3c35d99323","algorithm":{"pbkdf2_salt":"","pbkdf2_iterations":2048,"pbkdf2_hash_function":"SHA256","pbkdf2_phase1_key_length":16,"pbkdf2_phase2_key_length":32,"aes_iv":null,"aes_cipher":"AES-256-ECB","aes_auth_tag":null,"aes_auth_data":null}}')
    @pin = "deadbeef"
  end

  it "aes256ecb_success" do
    expect(BlockIo::Helper.dynamicExtractKey(@aes256ecb_user_key, @pin).public_key_hex).to eq(BlockIo::Key.from_passphrase("beadbeef").public_key_hex)
  end
  
  it "aes256cbc_success" do
    expect(BlockIo::Helper.dynamicExtractKey(@aes256cbc_user_key, @pin).public_key_hex).to eq(BlockIo::Key.from_passphrase("beadbeef").public_key_hex)
  end
  
  it "aes256gcm_success" do
    expect(BlockIo::Helper.dynamicExtractKey(@aes256gcm_user_key, @pin).public_key_hex).to eq(BlockIo::Key.from_passphrase("beadbeef").public_key_hex)
  end
  
end
