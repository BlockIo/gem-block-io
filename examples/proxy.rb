# creates a new destination address, withdraws from the default label to it,
# gets updated address balances, gets sent/received transactions, and the
# current price
# ... through an https proxy (like Squid)
#
# Unauthenticated:
# $ PROXY_HOST=localhost PROXY_PORT=3128 API_KEY=TESTNET_API_KEY PIN=YOUR_SECRET_PIN ruby proxy.rb
#
# Authenticated:
# $ PROXY_HOST=localhost PROXY_PORT=3128 PROXY_USER=user PROXY_PASS=pass API_KEY=TESTNET_API_KEY PIN=YOUR_SECRET_PIN ruby proxy.rb
#
# adjust amount below if not using the Dogecoin Testnet

require '../lib/block_io'

blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'], :pin => ENV['PIN'], :version => 2, :proxy => {
  :hostname => ENV['PROXY_HOST'],
  :port => ENV['PROXY_PORT'],
  :username => ENV['PROXY_USER'],
  :password => ENV['PROXY_PASS']
  })
puts blockio.get_balance
puts blockio.network

# create the address if it doesn't exist
puts blockio.get_new_address(:label => 'testDest')

puts blockio.withdraw_from_labels(:from_labels => 'default', :to_label => 'testDest', :amount => '2.5')

puts blockio.get_address_balance(:labels => 'default,testDest')

puts blockio.get_transactions(:type => 'sent')

puts blockio.get_transactions(:type => 'received')

puts blockio.get_current_price(:base_price => 'BTC')
