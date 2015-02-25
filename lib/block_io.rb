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
require_relative 'block_io/basic'
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

end

