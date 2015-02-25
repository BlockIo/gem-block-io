require 'httpclient'
require 'oj'
require 'oj_mimic_json'
require 'connection_pool'
require 'ecdsa'
require 'openssl'
require 'digest'
require 'pbkdf2'
require 'securerandom'
require 'base64'

require_relative 'block_io/version'
require_relative 'block_io/helper'
require_relative 'block_io/key'
require_relative 'block_io/dtrust'

module BlockIo

  class Vars
    # holds the variables we use
    class << self
      attr_accessor :api_key, :base_url, :pin, :encryption_key, :conn_pool, :version, :privkey_versions, :address_versions, :network
    end

  end

  def self.set_options(args = {})
    # initialize BlockIo

    Vars.api_key = args[:api_key]
    Vars.pin = args[:pin]
    Vars.encryption_key = Helper.pinToAesKey(Vars.pin) unless Vars.pin.nil?
    Vars.conn_pool = ConnectionPool.new(size: 1, timeout: 60) { HTTPClient.new }    
    Vars.version = args[:version] || 2 # default version is 2
    Vars.base_url = "https://block.io/api/VERSION/API_CALL/?api_key="

    Vars.privkey_versions = {
      'BTC' => '80',
      'BTCTEST' => 'ef',
      'DOGE' => '9e',
      'DOGETEST' => 'f1',
      'LTC' => 'b0',
      'LTCTEST' => 'ef'
    }

    Vars.address_versions = {
      'BTC' => '00',
      'BTCTEST' => '6f',
      'DOGE' => '1e',
      'DOGETEST' => '71',
      'LTC' => '30',
      'LTCTEST' => '6f'
    }

    response = Helper.api_call(['get_balance',""])
    Vars.network = response['data']['network'] if response['status'].eql?('success')
    
    response
  end

  def self.method_missing(m, *args, &block)      

    if ['withdraw', 'withdraw_from_address', 'withdraw_from_addresses', 'withdraw_from_user', 'withdraw_from_users', 'withdraw_from_label', 'withdraw_from_labels'].include?(m.to_s) then
      # need to withdraw from an address
      self.withdraw(args.first, m.to_s)

    elsif ['sweep_from_address'].include?(m.to_s) then
      # need to sweep from an address
      self.sweep(args.first, m.to_s)
    else
      Helper.api_call([m.to_s, Helper.get_params(args.first)])
    end
    
  end 

  def self.withdraw(args = {}, method_name = 'withdraw')
    # validate arguments for withdrawal of funds TODO

    raise Exception.new("PIN not set. Use BlockIo.set_options(:api_key=>'API KEY',:pin=>'SECRET PIN',:version=>'API VERSION')") if Vars.pin.nil?

    params = Helper.get_params(args)

    params << "&pin=" << Vars.pin if Vars.version == 1 # Block.io handles the Secret PIN in the legacy API (v1)

    response = Helper.api_call([method_name, params])
    
    if response['data'].key?('reference_id') then
      # Block.io's asking us to provide some client-side signatures, let's get to it

      # extract the passphrase
      encrypted_passphrase = response['data']['encrypted_passphrase']['passphrase']

      # let's get our private key
      key = Helper.extractKey(encrypted_passphrase, Vars.encryption_key)

      raise Exception.new('Public key mismatch for requested signer and ourselves. Invalid Secret PIN detected.') if key.public_key != response['data']['encrypted_passphrase']['signer_public_key']

      # let's sign all the inputs we can
      inputs = response['data']['inputs']

      Helper.signData(inputs, [key])

      # the response object is now signed, let's stringify it and finalize this withdrawal
      response = Helper.api_call(['sign_and_finalize_withdrawal',{:signature_data => response['data'].to_json}])

      # if we provided all the required signatures, this transaction went through
      # otherwise Block.io responded with data asking for more signatures
      # the latter will be the case for dTrust addresses
    end

    return response

  end

  def self.sweep(args = {}, method_name = 'sweep_from_address')
    # sweep coins from a given address + key

    raise Exception.new("No private_key provided.") unless args.key?(:private_key)

    key = Key.from_wif(args[:private_key])

    args[:public_key] = key.public_key # so Block.io can match things up
    args.delete(:private_key) # the key must never leave this machine

    params = get_params(args)

    response = Helper.api_call([method_name, params])
    
    if response['data'].key?('reference_id') then
      # Block.io's asking us to provide some client-side signatures, let's get to it

      # let's sign all the inputs we can
      inputs = response['data']['inputs']
      Helper.signData(inputs, [key])

      # the response object is now signed, let's stringify it and finalize this withdrawal
      response = Helper.api_call(['sign_and_finalize_sweep',{:signature_data => response['data'].to_json}])

      # if we provided all the required signatures, this transaction went through
      # otherwise Block.io responded with data asking for more signatures
      # the latter will be the case for dTrust addresses
    end

    return response

  end

end

