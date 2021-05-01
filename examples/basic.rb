# creates a new destination address, withdraws from the default label to it, gets updated address balances, gets sent/received transactions, and the current price
#
# basic example: $ API_KEY=TESTNET_API_KEY PIN=YOUR_SECRET_PIN ruby basic.rb
# bundler example: $ API_KEY=TESTNET_API_KEY PIN=YOUR_SECRET_PIN bundle exec ruby basic.rb
#
# adjust amount below if not using the Litecoin Testnet

require 'block_io'

blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'], :pin => ENV['PIN'])
puts blockio.get_balance
puts blockio.network

# create the address if it doesn't exist
begin
  puts blockio.get_new_address(:label => 'testDest')
rescue BlockIo::APIException => e
  puts e.to_s
end
puts " -- "

# retrieve unspent outputs and other relevant data to create and sign the transaction
# you will inspect the prepared transaction for things like network fees being paid, block.io fees being paid, validating what destination addresses receive how much, etc.
prepared_transaction = blockio.prepare_transaction(:to_label => 'testDest', :amount => '0.012345')
puts JSON.pretty_generate(prepared_transaction)
puts " -- "

# a summary of what's in the prepared transaction
# for in-depth review of the transaction, look at the prepared_transaction object yourself
puts JSON.pretty_generate(blockio.summarize_prepared_transaction(prepared_transaction))
puts " -- "

# once satisfied with the prepared transaction, create and sign it
# inspect this again if you wish, it will contain the transaction payload in hexadecimal form you want Block.io to sign and broadcast
transaction_data = blockio.create_and_sign_transaction(prepared_transaction)
puts JSON.pretty_generate(transaction_data)
puts " -- "

# ask Block.io to sign and broadcast the transaction
puts JSON.pretty_generate(blockio.submit_transaction(:transaction_data => transaction_data))
puts " -- "

puts blockio.get_address_balance(:labels => 'default,testDest')

puts blockio.get_transactions(:type => 'sent')

puts blockio.get_transactions(:type => 'received')

puts blockio.get_current_price(:base_price => 'BTC')

