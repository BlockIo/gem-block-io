
describe "Key.from_wif" do

  context "L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr" do
    
    before(:each) do
      @key = BlockIo::Key.from_wif("L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr")
    end
    
    it "match(public_key)" do
      expect(@key.public_key).to eq("024988bae7e0ade83cb1b6eb0fd81e6161f6657ad5dd91d216fbeab22aea3b61a0")
    end
    
    it "match(private_key)" do
      expect(@key.private_key).to eq("833e2256c42b4a41ee0a6ee284c39cf8e1978bc8e878eb7ae87803e22d48caa9")
    end
    
    it "sign_without_low_r" do
      expect(@key.sign("e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63",false)).to eq("3045022100aec97f7ad7a9831d583ca157284a68706a6ac4e76d6c9ee33adce6227a40e675022008894fb35020792c01443d399d33ffceb72ac1d410b6dcb9e31dcc71e6c49e92")
    end

    it "sign_with_low_r" do
      expect(@key.sign("e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63")).to eq("3044022061753424b6936ca4cfcc81b883dab55f16d84d3eaf9d5da77c1e25f54fda963802200d3db78e8f5aac62909c2a89ab1b2b413c00c0860926e824f37a19fa140c79f4")
    end
  end
  
end

describe "Key.from_passphrase" do

  context "deadbeef" do

    before(:each) do
      @key = BlockIo::Key.from_passphrase("deadbeef")
      @data = "e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63"
    end

    it "match(public_key)" do
      expect(@key.public_key).to eq("02953b9dfcec241eec348c12b1db813d3cd5ec9d93923c04d2fa3832208b8c0f84")
    end

    it "match(private_key)" do
      expect(@key.private_key).to eq("5f78c33274e43fa9de5659265c1d917e25c03722dcb0b8d27db8d5feaa813953")
    end
    
    it "sign_without_low_r" do
      expect(@key.sign(@data,false)).to eq("30450221009a68321e071c94e25484e26435639f00d23ef3fbe9c529c3347dc061f562530c0220134d3159098950b81b678f9e3b15e100f5478bb45345d3243df41ae616e70032")
    end
    
    it "sign_with_low_r" do
      expect(@key.sign(@data)).to eq("304402204ac97a4cdad5f842e745e27c3ffbe08b3704900baafab602277a5a196c3a4a3202202bacdf06afaf58032383447a9f3e9a42bfaeabf6dbcf9ab275d8f24171d272cf")
    end

    it "rfc6979_without_extra_entropy" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16)).to_s(16)
      expect(nonce).to eq("b13fa787e16b878c9a7815c8b508eb9e6a401432a15f340dd3fcde25e5c494b8")
    end

    it "rfc6979_with_extra_entropy_1" do
      # Key.deterministicGenerateK([data].pack("H*"), @private_key, counter)
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 1).to_s(16)
      expect(nonce).to eq("b69b1e880b537aca72b7235506ba04a676bdd2d663e4e1eb7d8c567f48ab0646")
    end

    it "rfc6979_with_extra_entropy_2" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 2).to_s(16)
      expect(nonce).to eq("e0b71534de1cf4f5019b0bc4e10d655d0e625b531e4911daf44cf2d065dcedd3")
    end
    
    it "rfc6979_with_extra_entropy_3" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 3).to_s(16)
      expect(nonce).to eq("faed0d38abb73e5f909cc989d967e3c4abb873ad177fe72bc35dc8ba42452fc0")
    end

    it "rfc6979_with_extra_entropy_4" do
      nonce = BlockIo::Key.send(:deterministicGenerateK, [@data].pack("H*"), @key.private_key.to_i(16), 4).to_s(16)
      expect(nonce).to eq("96db9090ce1eb13ae91fb15129838d73ba382cfeb48f6d1cf1a1296a3ce94c49")
    end

  end

end

