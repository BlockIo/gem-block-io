require_relative '../lib/block_io'

require 'webmock/rspec'

WebMock.disable_net_connect!

SPEC_REQUEST_HEADERS = BlockIo::Client.new(:api_key => "0000-0000-0000-0000").api_request_headers.freeze
