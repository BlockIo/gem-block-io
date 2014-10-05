# BlockIo

This Ruby Gem is the official reference client for the Block.io payments API. To use this, you will need the Dogecoin, Bitcoin, or Litecoin API key(s) from <a href="https://block.io" target="_blank">Block.io</a>. Go ahead, sign up :)

## Installation

Add this line to your application's Gemfile:

    gem 'block_io'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install block_io -v=1.0.1

## Changelog

*09/27/14*: Now supporting client-side signatures. API v2 recommended.
   
*07/01/14*: Forcing TLSv1 usage since Block.io does not support SSLv3 due to its vulnerable nature. Fixed:
	    HTTPClient.new.ssl_config.ssl_version = :TLSv1


## Usage

It's super easy to get started. In your Ruby shell ($ irb), for example, do this:

    require 'block_io'
    BlockIo.set_options :api_key => 'API KEY', :pin => 'SECRET PIN', :version => 2
     
And you're good to go:

    BlockIo.get_new_address
    BlockIo.get_my_addresses

For more information, see https://block.io/api/simple/ruby

## Contributing

1. Fork it ( https://github.com/BlockIo/gem-block-io/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
