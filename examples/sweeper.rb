# Example script for sweeping all coins from a given address
# Must use the API Key for the Network the address belongs to
# Must also provide the Private Key to the sweep address in Wallet Import Format (WIF)
#
# Contact support@block.io if you have any issues

require "block_io"

BlockIo.set_options :api_key => 'YOUR API KEY', :pin => 'PIN NOT NEEDED', :version => 2

to_address = 'SWEEP COINS TO THIS ADDRESS'

from_address = 'SWEEP COINS FROM THIS ADDRESS'
private_key = 'PRIVATE KEY FOR FROM_ADDRESS'

begin
  response = BlockIo.sweep_from_address(:to_address => to_address, :private_key => private_key, :from_address => from_address)
  
  puts "Sweep Complete: #{response['data']['amount_sent']} #{response['data']['network']} swept from #{from_address} to #{to_address}."
  puts "Transaction ID: #{response['data']['txid']}"
  puts "Network Fee Incurred: #{response['data']['network_fee']} #{response['data']['network']}"
rescue Exception => e
  puts "Sweep failed: #{e}"
end
