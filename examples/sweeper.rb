# Example script for sweeping all coins from a given address
# Must use the API Key for the Network the address belongs to
# Must also provide the Private Key to the sweep address in Wallet Import Format (WIF)
#
# Contact support@block.io if you have any issues

require 'block_io'

blockio = BlockIo::Client.new(:api_key => ENV['API_KEY'])

to_address = ENV['TO_ADDRESS'] # sweep coins into this address
private_key = ENV['PRIVATE_KEY'] # private key for the address from which you wish to sweep coins

begin
  
  prepare_transaction_response = blockio.prepare_sweep_transaction(:to_address => to_address, :private_key => private_key)
  
  raise response["data"]["error_message"] unless response["status"].eql?("success")
  
  puts JSON.pretty_generate(prepare_transaction_response)
  puts " -- "
  
  signed_transaction_response = blockio.create_and_sign_transaction(prepare_transaction_response)
  
  raise response["data"]["error_message"] unless response["status"].eql?("success")
  
  puts JSON.pretty_generate(signed_transaction_response)
  puts " -- "
  
  response = blockio.submit_transaction(signed_transaction_response)
  
  raise response["data"]["error_message"] unless response["status"].eql?("success")
  
  puts JSON.pretty_generate(submit_transaction_response)
  puts " -- "

  puts "Sweep Complete: #{response['data']['amount_sent']} #{response['data']['network']} swept to #{to_address}."
  puts "Transaction ID: #{response['data']['txid']}"
  puts "Network Fee Incurred: #{response['data']['network_fee']} #{response['data']['network']}"
  
rescue Exception => e
  puts "Sweep failed: #{e}"
end
