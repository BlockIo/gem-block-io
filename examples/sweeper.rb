# Example script for sweeping all coins from a given address
# Must use the API Key for the Network the address belongs to
# Must also provide the Private Key to the sweep address in Wallet Import Format (WIF)
#
# Contact support@block.io if you have any issues

require 'block_io'

blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'])

to_address = ENV['TO_ADDRESS'] # sweep coins into this address
private_key = ENV['PRIVATE_KEY'] # private key for the address from which you wish to sweep coins (WIF)

# prepare the sweep transaction
# you will inspect this data to ensure things are in order (the network fees you pay, the amount being swept, etc.)
# the private key is used to determine the public key by prepare_sweep_transaction client-side
# the private key never travels to Block.io
prepared_transaction = blockio.prepare_sweep_transaction(:to_address => to_address, :private_key => private_key)
puts JSON.pretty_generate(prepared_transaction)
puts " -- "

# create and sign the transaction
# the signature is from the key you provided to prepare_sweep_transaction above
transaction_data = blockio.create_and_sign_transaction(prepared_transaction)
puts JSON.pretty_generate(transaction_data)
puts " -- "

# submit the final transaction to Block.io for broadcast to the network, or
# submit the transaction payload youself elsewhere (like using sendrawtransaction RPC calls with bitcoind, dogecoind, litecoind, etc.)
response = blockio.submit_transaction(:transaction_data => transaction_data)
puts JSON.pretty_generate(response)
puts " -- "

puts "Transaction ID: #{response['data']['txid']}"
