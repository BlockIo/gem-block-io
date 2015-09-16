# 1. create an address (first_address), move all coins to it
# 2. create an address (second_address), as the change address for the first_address
# 3. send destination_amount to destination_address from first_address, and the rest of the coins to second_address
# 4. archive first_address since it will no longer be used

# execute with:
#    $ DESTINATION_ADDRESS=AN_ADDRESS DESTINATION_AMOUNT=COINS_TO_SEND_TO_DESTINATION_ADDRESS API_KEY=TESTNET_API_KEY PIN=YOUR_SECRET_PIN ruby change.rb

require 'block_io'
require 'securerandom'
require 'bigdecimal'

# please use the Dogecoin/Bitcoin Testnet API key here
BlockIo.set_options :api_key => ENV['API_KEY'], :pin => ENV['PIN'], :version => 2

# create address A, and withdraw all coins to address A
first_address_label = SecureRandom.hex(8) # the source address
second_address_label = SecureRandom.hex(8) # the change address

# let's fill up the first address with whatever coins exist in this account
puts BlockIo.get_new_address(:label => first_address_label)

available_balance = BigDecimal(BlockIo.get_balance()['data']['available_balance'])
network_fee = BigDecimal('0.0')

puts "Available Balance: #{available_balance.truncate(8).to_s('F')}"

options = {:to_labels => first_address_label, :amounts => available_balance.to_s("F")}

tries = 2 # retry twice at most

begin
  options[:amounts] = (available_balance - network_fee).truncate(8).to_s("F")
  
  response = BlockIo.get_network_fee_estimate(options)
  network_fee = BigDecimal(response['data']['estimated_network_fee'])
  
  puts "Final Network Fee: #{network_fee.truncate(8).to_s('F')}"
  
  options[:amounts] = (available_balance - network_fee).truncate(8).to_s("F")
rescue Exception => e
  # extract the fee and subtract it from the available amount
  
  network_fee = BigDecimal(e.to_s.split(' ')[7])
  puts "Estimated Network Fee: #{e.to_s.split(' ')[7]}"
  
  retry unless (tries -= 1).zero?
  
  raise Exception.new("UNABLE TO ESTIMATE NETWORK FEE")
end

# make the withdrawal
puts BlockIo.withdraw(options)

# all balance has been transferred to first_address_label

# create the change address
puts BlockIo.get_new_address(:label => second_address_label)

destination_address = ENV['DESTINATION_ADDRESS']
destination_amount = BigDecimal(ENV['DESTINATION_AMOUNT'])

puts "Sending #{destination_amount} to #{destination_address}"

available_balance = BigDecimal(BlockIo.get_balance(:labels => first_address_label)['data']['available_balance'])

second_address = BlockIo.get_address_by_label(:label => second_address_label)['data']['address']

options = {}

tries = 2 # two tries to estimate the correct network fee

network_fee = BigDecimal('0.0')

to_addresses = []
amounts = []

# estimate the fee for this withdrawal
begin
  
  change_amount = available_balance - destination_amount
  
  if change_amount - network_fee > 0 then
    to_addresses = [destination_address, second_address]
    amounts = [destination_amount.truncate(8).to_s("F"), (change_amount - network_fee).truncate(8).to_s("F")]
  else
    to_addresses = [destination_address]
    amounts = [destination_amount.truncate(8).to_s("F")]
  end
  
  response = BlockIo.get_network_fee_estimate(:from_labels => first_address_label, :to_addresses => to_addresses.join(','), :amounts => amounts.join(','))
  network_fee = BigDecimal(response['data']['estimated_network_fee'])
  
  puts "Final Network Fee: #{network_fee.truncate(8).to_s('F')}"
  
rescue Exception => e
  # extract the fee and subtract it from the available amount
  
  puts "Exception: #{e.to_s}"
  
  network_fee = BigDecimal(e.to_s.split(' ')[7])
  puts "Estimated Network Fee: #{e.to_s.split(' ')[7]}"
  
  retry unless (tries -= 1).zero?
  
  raise Exception.new("UNABLE TO ESTIMATE NETWORK FEE")
end

# make the withdrawal + send change to change address

puts BlockIo.withdraw(:from_labels => first_address_label, :to_addresses => to_addresses.join(','), :amounts => amounts.join(','))

# archive the first address

puts BlockIo.archive_address(:labels => first_address_label)


