# withdraws maximum balance to a given destination in a single transaction
# you will need to repeat this if a single transaction does not suffice for withdrawing the entire balance
# for error handling, please check response['data']['status'] != 'success'

require 'block_io'

blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'], :pin => ENV['PIN'], :version => 2)
puts blockio.get_balance
puts blockio.network

TO_ADDRESS = ENV['TO_ADDRESS']

raise "must specify a TO_ADDRESS" unless TO_ADDRESS.to_s.size > 0

total_balance = blockio.get_balance['data']['available_balance']

puts " -- total balance: #{total_balance} #{blockio.network}"

while true do
  response = blockio.withdraw(:to_address => TO_ADDRESS, :amount => total_balance)
  maximum_withdrawable_balance = response['data']['max_withdrawal_available']
  break if BigDecimal(maximum_withdrawable_balance).zero?
  puts blockio.withdraw(:to_address => TO_ADDRESS, :amount => maximum_withdrawable_balance)
end

final_balance = blockio.get_balance['data']['available_balance']

puts " -- final balance: #{final_balance} #{blockio.network}"

