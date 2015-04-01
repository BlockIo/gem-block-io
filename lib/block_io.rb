require 'oj'
require 'oj_mimic_json'
require 'connection_pool'
require 'ecdsa'
require 'openssl'
require 'digest'
require 'pbkdf2'
require 'securerandom'
require 'base64'
require 'faraday'

require_relative 'block_io/version'
require_relative 'block_io/helper'
require_relative 'block_io/key'
require_relative 'block_io/basic'
require_relative 'block_io/dtrust'

module BlockIo

  class Vars
    # holds the variables we use

    class << self
      attr_accessor :api_key, :base_path, :pin, :encryption_key, :conn_pool, :version, :privkey_versions, :address_versions, :network
    end

  end

  def self.set_options(args = {})
    # initialize BlockIo

    Vars.api_key = args[:api_key]
    Vars.pin = args[:pin]
    Vars.encryption_key = Helper.pinToAesKey(Vars.pin) unless Vars.pin.nil?

    Vars.conn_pool = ConnectionPool.new(size: 1, timeout: 60) {

      Faraday.new(:url => 'https://block.io') do |faraday|
        # TODO force TLSv1+
        faraday.request  :url_encoded             # form-encode POST params
#        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  args[:http_adapter] || Faraday.default_adapter  # make requests with Net::HTTP
      end

    }

    Vars.version = args[:version] || 2 # default version is 2
    Vars.base_path = "/api/VERSION/API_CALL/?api_key="

    Vars.privkey_versions = {
      'BTC' => '80',
      'BTCTEST' => 'ef',
      'DOGE' => '9e',
      'DOGETEST' => 'f1',
      'LTC' => 'b0',
      'LTCTEST' => 'ef'
    }

    Vars.address_versions = {
      'BTC' =>  {:pk => '00', :p2sh => '05'},
      'BTCTEST' => {:pk => '6f', :p2sh => 'c4'},
      'DOGE' => {:pk => '1e', :p2sh => '16'},
      'DOGETEST' => {:pk => '71', :p2sh => 'c4'},
      'LTC' => {:pk => '30', :p2sh => '05'},
      'LTCTEST' => {:pk => '6f', :p2sh => 'c4'}
    }

    response = args[:only_verify] ? Helper.api_call(['validate_api_key',""]) : Helper.api_call(['get_balance',""])
    Vars.network = response['data']['network'] if response['status'].eql?('success')
    
    response
  end

  # legacy method forwarders
  def self.get_new_address(args = {})
    BlockIo::Basic.get_new_address(args)
  end

  def self.withdraw(args = {})
    BlockIo::Basic.withdraw(args)
  end

  def self.withdraw_from_addresses(args = {})
    BlockIo::Basic.withraw_from_addresses(args)
  end

  def self.withdraw_from_address(args = {})
    BlockIo::Basic.withdraw_from_address(args)
  end

  def self.withdraw_from_labels(args = {})
    BlockIo::Basic.withdraw_from_labels(args)
  end

  def self.withdraw_from_label(args = {})
    BlockIo::Basic.withdraw_from_label(args)
  end

  def self.withdraw_from_users(args = {})
    BlockIo::Basic.withdraw_from_users(args)
  end

  def self.withdraw_from_user(args = {})
    BlockIo::Basic.withdraw_from_user(args)
  end

  def self.get_address_balance(args = {})
    BlockIo::Basic.get_address_balance(args)
  end

  def self.get_balance(args = {})
    BlockIo::Basic.get_balance(args)
  end

  def self.get_address_by_label(args = {})
    BlockIo::Basic.get_address_by_label(args)
  end

  def self.get_my_addresses(args = {})
    BlockIo::Basic.get_my_addresses(args)
  end

  def self.get_network_fee_estimate(args = {})
    BlockIo::Basic.get_network_fee_estimate(args)
  end

  def self.archive_address(args = {})
    BlockIo::Basic.archive_address(args)
  end

  def self.unarchive_address(args = {})
    BlockIo::Basic.unarchive_address(args)
  end

  def self.get_my_archived_addresses(args = {})
    BlockIo::Basic.get_my_archived_addresses(args)
  end

  def self.get_current_price(args = {})
    BlockIo::Basic.get_current_price(args)
  end

  def self.is_green_address(args = {})
    BlockIo::Basic.is_green_address(args)
  end

  def self.is_green_transaction(args = {})
    BlockIo::Basic.is_green_transaction(args)
  end

  def self.get_transactions(args = {})
    BlockIo::Basic.get_transactions(args)
  end

  def self.sweep_from_address(args = {})
    BlockIo::Basic.sweep_from_address(args)
  end

  def self.create_notification(args = {})
    BlockIo::Basic.create_notification(args)
  end

  def self.enable_notification(args = {})
    BlockIo::Basic.enable_notification(args)
  end

  def self.disable_notification(args = {})
    BlockIo::Basic.disable_notification(args)
  end

  def self.get_notifications(args = {})
    BlockIo::Basic.get_notifications(args)
  end

  def self.delete_notification(args = {})
    BlockIo::Basic.delete_notification(args)
  end

  def self.get_recent_notification_events(args = {})
    BlockIo::Basic.get_recent_notification_events(args)
  end

end

