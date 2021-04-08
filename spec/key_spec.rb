
describe "Key.from_wif" do

  context "L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr" do
    
    before(:each) do
      Bitcoin.chain_params = "BTC"
      @key_low_r = Bitcoin::Key.from_wif("L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr")
    end
    
    it "match(public_key)" do
      expect(@key_low_r.pubkey).to eq("024988bae7e0ade83cb1b6eb0fd81e6161f6657ad5dd91d216fbeab22aea3b61a0")
    end
    
    it "match(private_key)" do
      expect(@key_low_r.priv_key).to eq("833e2256c42b4a41ee0a6ee284c39cf8e1978bc8e878eb7ae87803e22d48caa9")
    end
    
    it "sign_with_low_r" do
      expect(@key_low_r.sign(["e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63"].pack("H*")).unpack("H*")[0]).to eq("3044022061753424b6936ca4cfcc81b883dab55f16d84d3eaf9d5da77c1e25f54fda963802200d3db78e8f5aac62909c2a89ab1b2b413c00c0860926e824f37a19fa140c79f4")
    end
  end
  
end

describe "Key.from_passphrase" do

  context "deadbeef" do

    before(:each) do
      @key_low_r = BlockIo::Key.from_passphrase("deadbeef")
      @data = "e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63"
    end

    it "match(public_key)" do
      expect(@key_low_r.pubkey).to eq("02953b9dfcec241eec348c12b1db813d3cd5ec9d93923c04d2fa3832208b8c0f84")
    end

    it "match(private_key)" do
      expect(@key_low_r.priv_key).to eq("5f78c33274e43fa9de5659265c1d917e25c03722dcb0b8d27db8d5feaa813953")
    end
    
    it "sign_with_low_r" do
      expect(@key_low_r.sign([@data].pack("H*")).unpack("H*")[0]).to eq("304402204ac97a4cdad5f842e745e27c3ffbe08b3704900baafab602277a5a196c3a4a3202202bacdf06afaf58032383447a9f3e9a42bfaeabf6dbcf9ab275d8f24171d272cf")
    end

  end

end

describe "Key.generate" do

  context "compressed" do

    before(:each) do
      Bitcoin.chain_params = "BTC"
      @key = Bitcoin::Key.generate
    end

    it "compressed?" do
      expect(@key.compressed?).to eq(true)
    end
    
  end

  context "uncompressed" do
    Bitcoin.chain_params = "BTC"
  end

  it "raises_exception" do
    expect {Bitcoin::Key.generate(0x00)}.to raise_error(RuntimeError, "key_type must always be 0x01 (compressed)")
  end
end
