# creates a new destination address, withdraws from the default label to it, gets sent transactions, and the current price

require 'block_io'
require 'json'

# please use the Dogecoin Testnet API key here
puts "*** Initialize BlockIo library: "
puts JSON.pretty_generate(BlockIo.set_options :api_key => 'YourDogecoinTestnetAPIKey', :pin => 'YourSecretPIN', :version => 2)


# create 4 keys
keys = [ BlockIo::Key.from_passphrase('alpha1alpha2alpha3alpha4'), BlockIo::Key.from_passphrase('alpha4alpha1alpha2alpha3'), BlockIo::Key.from_passphrase('alpha3alpha4alpha1alpha2'), BlockIo::Key.from_passphrase('alpha2alpha3alpha4alpha1') ]

dtrust_address = nil

begin
  # let's create a new address with all 4 keys as signers, but only 3 signers required (i.e., 4 of 5 multisig, with 1 signature being Block.io)

  signers = ""
  keys.each { |key| signers += ',' if signers.length > 0; signers += key.public_key; }

  response = BlockIo.get_new_dtrust_address(:label => 'dTrust1', :public_keys => signers, :required_signatures => 3)

  dtrust_address = response['data']['address']
rescue Exception => e
  # if this failed, we probably created the same label before. let's fetch the address then.
  puts e.to_s
  
  response = BlockIo.get_dtrust_address_by_label(:label => 'dTrust1')
  
  dtrust_address = response['data']['address']
end

puts "*** Our dTrust Address: #{dtrust_address}"

# let's deposit some coins into this new address
response = BlockIo.withdraw_from_labels(:from_labels => 'default', :to_address => dtrust_address, :amount => '3.5')

puts "*** Withdrawal response:"
puts JSON.pretty_generate(response)


# fetch the dtrust address' balance
puts "*** dTrust1 Balance:"
puts JSON.pretty_generate(BlockIo.get_dtrust_address_balance(:label => 'dTrust1'))

# withdraw a few coins from dtrust1 to the default label
normal_address = BlockIo.get_address_by_label(:label => 'default')['data']['address']

puts "*** Withdrawing from dTrust1 to the 'default' label in normal multisig"

response = BlockIo.withdraw_from_dtrust_address(:from_labels => 'dTrust1', :to_addresses => normal_address, :amounts => '2.1')

puts JSON.pretty_generate(response)

# let's sign for the public keys specified

response['data']['inputs'].each do |input|
  # for each input

  data_to_sign = input['data_to_sign']

  input['signers'].each do |signer|

    # figure out if we have the public key that matches this signer
    
    keys.each do |key|
      # iterate over all keys till we've found the one that we need

      signer['signed_data'] = key.sign(data_to_sign) if key.public_key == signer['signer_public_key']

    end

  end

end

puts "*** Our signed response: "
puts JSON.pretty_generate(response['data']) #.to_json

# let's final the withdrawal
puts "*** Finalize withdrawal: "
puts JSON.pretty_generate(BlockIo.sign_and_finalize_withdrawal(:signature_data => response['data'].to_json))

# get the sent transactions for this dTrust address

puts "*** Get transactions sent by our dTrust1 address: "

puts JSON.pretty_generate(BlockIo.get_dtrust_transactions(:type => 'sent', :labels => 'dTrust1'))

