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
# you will generate your own private keys, for instance: SecureRandom.hex(64). Just note them down somewhere safe before you use them to generate dTrust addresses.
# WARNING: The phrases below are just for demonstration, DO NOT use them on mainnets, DO NOT use insecurely generated keys
keys = [ BlockIo::Key.from_passphrase('alpha1alpha2alpha3alpha4'), BlockIo::Key.from_passphrase('alpha4alpha1alpha2alpha3'), BlockIo::Key.from_passphrase('alpha3alpha4alpha1alpha2'), BlockIo::Key.from_passphrase('alpha2alpha3alpha4alpha1') ]

dtrust_address = nil
dtrust_address_label = "dTrust1_witness_v0"

begin
  # let's create a new address with all 4 keys as signers, but only 3 signers required (i.e., 4 of 5 multisig, with 1 signature being Block.io)

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
BlockIo::Helper.signData(response["data"]["inputs"], keys)

puts "*** Our signed response: "
puts JSON.pretty_generate(response['data'])

# let's final the withdrawal
puts "*** Finalize withdrawal: "
puts JSON.pretty_generate(blockio.sign_and_finalize_withdrawal(:signature_data => response['data'].to_json))

# get the sent transactions for this dTrust address

puts "*** Get transactions sent by our dtrust_address_label address: "

puts JSON.pretty_generate(blockio.get_dtrust_transactions(:type => 'sent', :labels => dtrust_address_label))

