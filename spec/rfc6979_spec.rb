describe "RFC6979" do

  context "deadbeef" do

    before(:each) do
      @key = BlockIo::Key.from_passphrase("deadbeef")
      @data = "e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63"
    end

    it "without_extra_entropy" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16)).to_s(16)
      expect(nonce).to eq("b13fa787e16b878c9a7815c8b508eb9e6a401432a15f340dd3fcde25e5c494b8")
    end

    it "with_extra_entropy_1" do
      # Key.deterministicGenerateK([data].pack("H*"), @private_key, counter)
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 1).to_s(16)
      expect(nonce).to eq("b69b1e880b537aca72b7235506ba04a676bdd2d663e4e1eb7d8c567f48ab0646")
    end

    it "with_extra_entropy_2" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 2).to_s(16)
      expect(nonce).to eq("e0b71534de1cf4f5019b0bc4e10d655d0e625b531e4911daf44cf2d065dcedd3")
    end
    
    it "with_extra_entropy_3" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 3).to_s(16)
      expect(nonce).to eq("faed0d38abb73e5f909cc989d967e3c4abb873ad177fe72bc35dc8ba42452fc0")
    end

    it "with_extra_entropy_4" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 4).to_s(16)
      expect(nonce).to eq("96db9090ce1eb13ae91fb15129838d73ba382cfeb48f6d1cf1a1296a3ce94c49")
    end

    it "with_extra_entropy_16" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16),16).to_s(16)
      expect(nonce).to eq("d4985f135357c3885c55c3dff3e9f98bccb0264fb348259f8160660e41f5ce65")
    end

    it "with_extra_entropy_17" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16),17).to_s(16)
      expect(nonce).to eq("1affb74f0ecffa9b1996670ba47c6366dd76b484f7af977e4cd32d16c5545e0d")
    end

    it "with_extra_entropy_255" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16),255).to_s(16)
      expect(nonce).to eq("d72decc0d526ece67755680556b8700ccfdd2fd7beba87f709ec4037f7a0771f")
    end
    
    it "with_extra_entropy_256" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16),256).to_s(16)
      expect(nonce).to eq("5ff357395dc803f98967276a49a0802cc5b44b52db395242926bd2c4a6ac062f")
    end
    
  end

end

