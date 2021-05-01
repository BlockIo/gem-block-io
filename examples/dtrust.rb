# creates a new dTrust destination address, sends coins to it, withdraws coins from it, gets sent transactions, and the current price

require 'block_io'
require 'json'

# please use the Litecoin Testnet API key here
puts "*** Initialize BlockIo library: "
blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'], :pin => ENV['PIN'])

puts blockio.get_dtrust_balance
puts blockio.network

raise "Please use the LTCTEST network API Key here or modify this script for another network." unless blockio.network == "LTCTEST"

# create 4 keys
# you will generate your own private keys, for instance: key = BlockIo::Key.generate.
# you will need to record key.to_wif (private key in Wallet Import Format (WIF)) somewhere safe before you use your keys to generate dTrust addresses.
# if you already have hex private keys, load the keys (see below). Ensure the key's public_key (key.public_key_hex) matches what you expect.
# WARNING: The keys below are just for demonstration, DO NOT use them on mainnets, DO NOT use insecurely generated keys
# WARNING: You must ALWAYS use compressed public keys. Use of uncompressed public keys can lead to lost coins when using SegWit addresses.

# these keys will use the appropriate coin's parameters. The library will know what network you're interacting with once you make a successful API call first, like blockio.get_dtrust_balance above

keys = [
  "b515fd806a662e061b488e78e5d0c2ff46df80083a79818e166300666385c0a2", # alpha1alpha2alpha3alpha4
  "1584b821c62ecdc554e185222591720d6fe651ed1b820d83f92cdc45c5e21f", # alpha2alpha3alpha4alpha1
  "2f9090b8aa4ddb32c3b0b8371db1b50e19084c720c30db1d6bb9fcd3a0f78e61", # alpha3alpha4alpha1alpha2
  "6c1cefdfd9187b36b36c3698c1362642083dcc1941dc76d751481d3aa29ca65" # alpha4alpha1alpha2alpha3
].freeze

dtrust_address = nil
dtrust_address_label = "dTrust1_witness_v0"

begin
  # let's create a new address with all 4 keys as signers, but only 3 signers required (i.e., 4 of 5 multisig, with 1 signature being Block.io)
  # you will need all 4 of your keys to use your address without interacting with Block.io

  signers = keys.map{|x| BlockIo::Key.from_private_key_hex(x)}.map(&:public_key_hex).join(',')

  response = blockio.get_new_dtrust_address(:label => dtrust_address_label, :public_keys => signers, :required_signatures => 3, :address_type => "witness_v0")

  dtrust_address = response['data']['address']

rescue BlockIo::APIException => e
  # if this failed, we probably created the same label before. let's fetch the address then.
  puts e.to_s
  
  response = blockio.get_dtrust_address_by_label(:label => dtrust_address_label)
  
  dtrust_address = response['data']['address']
end

puts "*** Our dTrust Address: #{dtrust_address}"

# let's deposit some coins into this new address

# blockio.prepare_transaction gets the appropriate data you need to create and sign your transaction. You will need to inspect it to ensure things are as expected yourself.
prepared_transaction = blockio.prepare_transaction(:to_address => dtrust_address, :amount => '0.001')

puts JSON.pretty_generate(prepared_transaction)
puts " -- "

puts JSON.pretty_generate(blockio.summarize_prepared_transaction(prepared_transaction))
puts " -- "

# blockio.create_and_sign_transaction creates the transaction client-side, and appends your signatures (if any)
transaction_data = blockio.create_and_sign_transaction(prepared_transaction)

# blockio.submit_transaction sends the signatures and transaction payload to Block.io so Block.io can add its signatures and broadcast the transaction to the network
response = blockio.submit_transaction(:transaction_data => transaction_data)

puts "*** Withdrawal response:"
puts JSON.pretty_generate(response)


# fetch the dtrust address' balance
puts "*** dtrust_address_label Balance:"
puts JSON.pretty_generate(blockio.get_dtrust_address_balance(:label => dtrust_address_label))

# withdraw a few coins from dtrust_address_label to the default label
normal_address = blockio.get_address_by_label(:label => 'default')['data']['address']

puts "*** Withdrawing from dtrust_address_label to the 'default' label in normal multisig"

# note use of prepare_dtrust_transaction instead of prepare_transaction, since this is a dTrust transaction
# we're not doing any inspection here, but you will in your own code
prepared_transaction = blockio.prepare_dtrust_transaction(:from_labels => dtrust_address_label, :to_addresses => normal_address, :amounts => '0.0009')

# create the transaction and sign it with the keys we've provided
# we're signing the transaction partially by supplying only 3 of our 4 keys
transaction_data = blockio.create_and_sign_transaction(prepared_transaction, keys.first(3))

puts "*** Submitting transaction data:"
puts JSON.pretty_generate(transaction_data)

# if successful, you will get a transaction ID when you submit_transaction.
response = blockio.submit_transaction(:transaction_data => transaction_data)

# let's final the withdrawal
puts "*** Submit the transaction: "
puts JSON.pretty_generate(response)

# get the sent transactions for this dTrust address

puts "*** Get transactions sent by our dtrust_address_label address: "
puts JSON.pretty_generate(blockio.get_dtrust_transactions(:type => 'sent', :labels => dtrust_address_label))

