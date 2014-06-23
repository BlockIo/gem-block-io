require "block_io/version"
require 'httpclient'
require 'json'

module BlockIo

  @api_key = API_KEY
  @base_url = "https://block.io:99/api/v1/API_CALL/?api_key="

  def self.get_balance
    endpoint = ["get_balance", ""] 
    self.api_call(endpoint)
  end

  def self.withdraw(payment_address, amount, pin)
    endpoint = ["withdraw","&amount=#{amount}&payment_address=#{payment_address}&pin=#{pin}"] 
    self.api_call(endpoint)
  end

  def self.get_new_address(address_label=nil)
    endpoint = ["get_new_address","&address_label=#{address_label}"]
    self.api_call(endpoint)
  end

  def self.get_my_addresses
    endpoint = ["get_my_addresses",""]
    self.api_call(endpoint)
  end

  def self.get_address_received(address_label)
    endpoint = ["get_address_received","&address_label=#{address_label}"]
    self.api_call(endpoint)
  end

  def self.get_address_by_label(address_label)
    endpoint = ["get_address_by_label","&address_label=#{address_label}"]
    self.api_call(endpoint)
  end

  private

  def self.api_call(endpoint)
    hc = HTTPClient.new
        
    response = hc.get("#{@base_url.gsub('API_CALL',endpoint[0]) + @api_key + endpoint[1]}")
    JSON.parse(response.body)
  end

end
