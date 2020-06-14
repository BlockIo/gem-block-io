require_relative '../lib/block_io'

describe "generate public key from base58 key" do
  it "generates public key for given base58 key" do
    key = BlockIo::Key.from_wif("L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr")
    expect(key.public_key).to eq("024988bae7e0ade83cb1b6eb0fd81e6161f6657ad5dd91d216fbeab22aea3b61a0")
  end
end

describe "generate private key from base58 key" do
  it "extracts private key from given base58 key" do
    key = BlockIo::Key.from_wif("L1cq4uDmSKMiViT4DuR8jqJv8AiiSZ9VeJr82yau5nfVQYaAgDdr")
    expect(key.private_key).to eq("833e2256c42b4a41ee0a6ee284c39cf8e1978bc8e878eb7ae87803e22d48caa9")
  end
end

describe "generate public key from passphrase" do
  it "generates a public key from a given passphrase" do
    key = BlockIo::Key.from_passphrase("deadbeef")
    expect(key.public_key).to eq("02953b9dfcec241eec348c12b1db813d3cd5ec9d93923c04d2fa3832208b8c0f84")
  end
end

describe "generate a deterministic signature" do
  it "generates a valid, deterministic signature for given data using deadbeef passphrase" do
    key = BlockIo::Key.from_passphrase("deadbeef")
    expect(key.sign("e76f0f78b7e7474f04cc14ad1343e4cc28f450399a79457d1240511a054afd63")).to eq("30450221009a68321e071c94e25484e26435639f00d23ef3fbe9c529c3347dc061f562530c0220134d3159098950b81b678f9e3b15e100f5478bb45345d3243df41ae616e70032")
  end
end
