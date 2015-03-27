# creates a new destination address, withdraws from the default label to it, gets sent transactions, and the current price

require 'block_io'

# please use the Dogecoin Testnet API key here
puts BlockIo.set_options :api_key => ENV['API_KEY'] || 'YOURDOGECOINTESTNETAPIKEY', :pin => ENV['SECRET_PIN'] || 'YOURSECRETPIN', :version => 2

begin
  puts BlockIo.get_new_address(:label => 'testDest')
rescue Exception => e
  # if this failed, we probably created testDest label before
  puts e.to_s
end

puts BlockIo.withdraw_from_labels(:from_labels => 'default', :to_label => 'testDest', :amount => '3.5')

puts BlockIo.get_address_by_label(:label => 'default')

puts BlockIo.get_transactions(:type => 'sent') # API v2 only

puts BlockIo.get_current_price(:base_price => 'BTC')

