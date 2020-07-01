
describe "Key.from_wif" do

  context "L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr" do
    
    before(:each) do
      @key_any_r = BlockIo::Key.from_wif("L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr", false)
      @key_low_r = BlockIo::Key.from_wif("L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr")
    end
    
    it "match(public_key)" do
      expect(@key_any_r.public_key).to eq("024988bae7e0ade83cb1b6eb0fd81e6161f6657ad5dd91d216fbeab22aea3b61a0")
      expect(@key_low_r.public_key).to eq("024988bae7e0ade83cb1b6eb0fd81e6161f6657ad5dd91d216fbeab22aea3b61a0")
    end
    
    it "match(private_key)" do
      expect(@key_any_r.private_key).to eq("833e2256c42b4a41ee0a6ee284c39cf8e1978bc8e878eb7ae87803e22d48caa9")
      expect(@key_low_r.private_key).to eq("833e2256c42b4a41ee0a6ee284c39cf8e1978bc8e878eb7ae87803e22d48caa9")
    end
    
    it "sign_without_low_r" do
      expect(@key_any_r.sign("e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63")).to eq("3045022100aec97f7ad7a9831d583ca157284a68706a6ac4e76d6c9ee33adce6227a40e675022008894fb35020792c01443d399d33ffceb72ac1d410b6dcb9e31dcc71e6c49e92")
    end

    it "sign_with_low_r" do
      expect(@key_low_r.sign("e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63")).to eq("3044022061753424b6936ca4cfcc81b883dab55f16d84d3eaf9d5da77c1e25f54fda963802200d3db78e8f5aac62909c2a89ab1b2b413c00c0860926e824f37a19fa140c79f4")
    end
  end
  
end

describe "Key.from_passphrase" do

  context "deadbeef" do

    before(:each) do
      @key_any_r = BlockIo::Key.from_passphrase("deadbeef", false)
      @key_low_r = BlockIo::Key.from_passphrase("deadbeef")
      @data = "e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63"
    end

    it "match(public_key)" do
      expect(@key_low_r.public_key).to eq("02953b9dfcec241eec348c12b1db813d3cd5ec9d93923c04d2fa3832208b8c0f84")
    end

    it "match(private_key)" do
      expect(@key_low_r.private_key).to eq("5f78c33274e43fa9de5659265c1d917e25c03722dcb0b8d27db8d5feaa813953")
    end
    
    it "sign_without_low_r" do
      expect(@key_any_r.sign(@data)).to eq("30450221009a68321e071c94e25484e26435639f00d23ef3fbe9c529c3347dc061f562530c0220134d3159098950b81b678f9e3b15e100f5478bb45345d3243df41ae616e70032")
    end
    
    it "sign_with_low_r" do
      expect(@key_low_r.sign(@data)).to eq("304402204ac97a4cdad5f842e745e27c3ffbe08b3704900baafab602277a5a196c3a4a3202202bacdf06afaf58032383447a9f3e9a42bfaeabf6dbcf9ab275d8f24171d272cf")
    end

  end

end

