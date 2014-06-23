require "block_io/version"
require 'httpclient'
require 'json'
require 'connection_pool'

module BlockIo

  @api_key = nil
  @base_url = "https://block.io:99/api/v1/API_CALL/?api_key="
  @pin = nil
  @conn_pool = nil

  def self.set_options(args = {})
    # initialize BlockIo
    @api_key = args[:api_key]
    @pin = args[:pin]
    @conn_pool = ConnectionPool.new(size: 5, timeout: 300) { HTTPClient.new }

    self.api_call(['get_balance',""])
  end

  def self.get_balance
    # returns the balances for your account tied to the API key
    endpoint = ["get_balance", ""] 
    self.api_call(endpoint)
  end

  def self.get_user_balance(args)
    # returns the specified user's balance
    
    user_id = args[:user_id]

    raise Exception.new("Must provide user_id") if user_id.nil?

    endpoint = ['get_user_balance',"&user_id=#{user_id}"]

    self.api_call(endpoint)
  end

  def self.get_address_balance(args)
    # returns the specified address or address_label's balance
    
    address = args[:address]
    address_label = args[:address_label]

    raise Exception.new("Must provide ONE of address or address_label") if (!address.nil? and !address_label.nil?) or (address.nil? and address_label.nil?)

    endpoint = ['get_address_balance',"&address=#{address}"] unless address.nil?
    endpoint = ['get_address_balance',"&address_label=#{address_label}"] unless address_label.nil?

    self.api_call(endpoint)
  end

  def self.get_current_price(args = {})
    # returns prices from different exchanges as an array of hashes
    price_base = args[:price_base]

    endpoint = ['get_current_price', '']
    endpoint = ['get_current_price',"&price_base=#{price_base}"] unless price_base.nil? or price_base.to_s.length == 0

    self.api_call(endpoint)
  end

  def self.withdraw(args = {})
    # validate arguments for withdrawal of funds TODO

    raise Exception.new("PIN not set. Use BlockIo.set_options(:api_key=>'API KEY',:pin=>'SECRET PIN')") if @pin.nil?

    # validate argument sets
    amount = args[:amount]
    to_user_id = args[:to_user_id]
    payment_address = args[:payment_address]
    from_user_ids = args[:from_user_ids] || args[:from_user_id]

    raise Exception.new("Must provide ONE of payment_address, or to_user_id") if (!to_user_id.nil? and !payment_address.nil?) or (to_user_id.nil? and payment_address.nil?)
    raise Exception.new("Must provide amount to withdraw") if amount.nil?

    endpoint = ['withdraw',"&amount=#{amount}&payment_address=#{payment_address}&pin=#{@pin}"] unless payment_address.nil?
    endpoint = ['withdraw',"&amount=#{amount}&to_user_id=#{to_user_id}&pin=#{@pin}"] unless to_user_id.nil?
    endpoint = ['withdraw',"&amount=#{amount}&from_user_ids=#{from_user_ids}&pin=#{@pin}&payment_address=#{payment_address}"] unless from_user_ids.nil? or payment_address.nil?
    endpoint = ['withdraw',"&amount=#{amount}&from_user_ids=#{from_user_ids}&to_user_id=#{to_user_id}&pin=#{@pin}"] unless to_user_id.nil? or from_user_ids.nil?

    self.api_call(endpoint)
  end

  def self.get_new_address(args = {})
    # validate arguments for getting a new address
    address_label = args[:address_label]

    endpoint = ['get_new_address','']
    endpoint = ["get_new_address","&address_label=#{address_label}"] unless address_label.nil?

    self.api_call(endpoint)
  end

  def self.create_user(args = {})
    # validate arguments for getting a new address
    address_label = args[:address_label]

    endpoint = ['create_user','']
    endpoint = ['create_user',"&address_label=#{address_label}"] unless address_label.nil?

    self.api_call(endpoint)
  end  

  def self.get_my_addresses(args = {})
    # returns all the addresses in your account tied to the API key
    endpoint = ["get_my_addresses",""]

    self.api_call(endpoint)
  end

  def self.get_users(args = {})
    # returns all the addresses in your account tied to the API key
    endpoint = ['get_users',""]

    self.api_call(endpoint)
  end

  def self.get_address_received(args = {})
    # get coins received, confirmed and unconfirmed, by the given address, address_label, or user_id
    address_label = args[:address_label]
    user_id = args[:user_id]
    address = args[:address]

    raise Exception.new("Must provide ONE of address_label, user_id, or address") unless args.keys.length == 1 and (!address_label.nil? or !user_id.nil? or !address.nil?)

    endpoint = ['get_address_received','']
    endpoint = ["get_address_received","&user_id=#{user_id}"] unless user_id.nil?
    endpoint = ['get_address_received',"&address_label=#{address_label}"] unless address_label.nil?
    endpoint = ['get_address_received',"&address=#{address}"] unless address.nil?

    self.api_call(endpoint)
  end

  def self.get_user_received(args = {})
    # returns the user's received coins, confirmed and unconfirmed

    user_id = args[:user_id]

    raise Exception.new("Must provide user_id") if user_id.nil?

    self.get_address_received(:user_id => user_id)
  end

  def self.get_address_by_label(args = {})
    # get address by label

    address_label = args[:address_label]

    raise Exception.new("Must provide address_label") if address_label.nil?

    endpoint = ["get_address_by_label","&address_label=#{address_label}"]

    self.api_call(endpoint)
  end

  def self.get_user_address(args = {})
    # gets the user's address

    user_id = args[:user_id]

    raise Exception.new("Must provide user_id") if user_id.nil?

    endpoint = ['get_user_address',"&user_id=#{user_id}"]

    self.api_call(endpoint)
  end

  private

  def self.api_call(endpoint)

    @conn_pool.with do |hc|
      # prevent initiation of HTTPClients every time we make this call, use a connection_pool

      response = hc.get("#{@base_url.gsub('API_CALL',endpoint[0]) + @api_key + endpoint[1]}")
      body = JSON.parse(response.body)
      body['data']
    end

  end

end
