# creates a new destination address, withdraws from the default label to it, gets sent transactions, and the current price

require 'block_io'
require 'json'

# please use the Litecoin Testnet API key here
puts "*** Initialize BlockIo library: "
blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'], :pin => ENV['PIN'], :version => 2)
puts blockio.get_dtrust_balance
puts blockio.network

raise "Please use the LTCTEST network API Key here or modify this script for another network." unless blockio.network == "LTCTEST"

# create 4 keys
# you will generate your own private keys, for instance: key = BlockIo::Key.new. Just note down key.public_key and key.private_key somewhere safe before you use your keys to generate dTrust addresses.
# if you already have hex private keys, load the keys with BlockIo::Key.new(private_key_hex). Ensure the key's .public_key matches what you expect.
# WARNING: The keys below are just for demonstration, DO NOT use them on mainnets, DO NOT use insecurely generated keys
keys = [
  BlockIo::Key.new("b515fd806a662e061b488e78e5d0c2ff46df80083a79818e166300666385c0a2"), # alpha1alpha2alpha3alpha4
  BlockIo::Key.new("1584b821c62ecdc554e185222591720d6fe651ed1b820d83f92cdc45c5e21f"), # alpha2alpha3alpha4alpha1
  BlockIo::Key.new("2f9090b8aa4ddb32c3b0b8371db1b50e19084c720c30db1d6bb9fcd3a0f78e61"), # alpha3alpha4alpha1alpha2
  BlockIo::Key.new("6c1cefdfd9187b36b36c3698c1362642083dcc1941dc76d751481d3aa29ca65") # alpha4alpha1alpha2alpha3
].freeze

dtrust_address = nil
dtrust_address_label = "dTrust1_witness_v0"

begin
  # let's create a new address with all 4 keys as signers, but only 3 signers required (i.e., 4 of 5 multisig, with 1 signature being Block.io)
  # you will need all 4 of your keys to use your address without interacting with Block.io

  signers = keys.map{|k| k.public_key}.join(',')

  response = blockio.get_new_dtrust_address(:label => dtrust_address_label, :public_keys => signers, :required_signatures => 3, :address_type => "witness_v0")

  dtrust_address = response['data']['address']

  raise response["data"]["error_message"] unless response["status"].eql?("success")
  
rescue Exception => e
  # if this failed, we probably created the same label before. let's fetch the address then.
  puts e.to_s
  
  response = blockio.get_dtrust_address_by_label(:label => dtrust_address_label)
  
  dtrust_address = response['data']['address']
end

puts "*** Our dTrust Address: #{dtrust_address}"

# let's deposit some coins into this new address
response = blockio.withdraw_from_labels(:from_labels => 'default', :to_address => dtrust_address, :amount => '0.001')

puts "*** Withdrawal response:"
puts JSON.pretty_generate(response)


# fetch the dtrust address' balance
puts "*** dtrust_address_label Balance:"
puts JSON.pretty_generate(blockio.get_dtrust_address_balance(:label => dtrust_address_label))

# withdraw a few coins from dtrust_address_label to the default label
normal_address = blockio.get_address_by_label(:label => 'default')['data']['address']

puts "*** Withdrawing from dtrust_address_label to the 'default' label in normal multisig"

response = blockio.withdraw_from_dtrust_address(:from_labels => dtrust_address_label, :to_addresses => normal_address, :amounts => '0.0009')

puts JSON.pretty_generate(response)

# let's sign for the public keys specified
signatures_added = BlockIo::Helper.signData(response["data"]["inputs"], keys)

puts "*** Signatures added? #{signatures_added}"

puts "*** Our (signed) request:"
puts JSON.pretty_generate(response['data'])

# let's final the withdrawal
puts "*** Finalize withdrawal: "
puts JSON.pretty_generate(blockio.sign_and_finalize_withdrawal({:signature_data => response["data"]}))

# get the sent transactions for this dTrust address

puts "*** Get transactions sent by our dtrust_address_label address: "

puts JSON.pretty_generate(blockio.get_dtrust_transactions(:type => 'sent', :labels => dtrust_address_label))

