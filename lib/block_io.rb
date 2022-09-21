require "oj"
require "bitcoin"
require "openssl"
require "securerandom"
require "typhoeus"

require_relative "block_io/version"
require_relative "block_io/helper"
require_relative "block_io/key"
require_relative "block_io/client"
require_relative "block_io/api_exception"
require_relative "block_io/extended_bitcoinrb"

module BlockIo

  def self.version
    BlockIo::VERSION
  end
  
end


