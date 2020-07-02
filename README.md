# BlockIo

This Ruby Gem is the official reference client for the Block.io payments API. To use this, you will need the Dogecoin, Bitcoin, or Litecoin API key(s) from <a href="https://block.io" target="_blank">Block.io</a>. Go ahead, sign up :)

## Installation

Add this line to your application's Gemfile:

    gem 'block_io'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install block_io -v=2.0.0

## Changelog

*07/02/20*: BREAKING CHANGES. Version 2.0.0. Remove support for Ruby < 2.3.0. Behavior and interfaces have changed. By upgrading you'll need to revise your code and tests.  
*05/10/19*: Prevent inadvertent passing of PINs (user error).  
*06/25/18*: Remove support for Ruby < 1.9.3 (OpenSSL::Cipher::Cipher). Remove connection_pool dependency.  
*01/21/15*: Added ability to sweep coins from one address to another.  
*11/04/14*: Fix issue with nil parameters in an API call.  
*11/03/14*: Reduce dependence on OpenSSL. PBKDF2 function is now Ruby-based. Should work well with Heroku's libraries.  
*10/18/14*: Now using deterministic signatures (RFC6979), and BIP62 to hinder transaction malleability.  


## Usage

It's super easy to get started. In your Ruby shell ($ irb), for example, do this:

    require 'block_io'
    blockio = BlockIo::Client.new(:api_key => "API KEY", :pin => "SECRET PIN")

If you do not have your PIN, or just wish to use your private key backup directly, do this:

    blockio = BlockIo::Client.new(:api_key => "API KEY", :keys => [BlockIo::Key.from_wif("PRIVATE KEY BACKUP")])

And you're good to go:

    blockio.get_new_address
    blockio.get_my_addresses

For other initialization options/parameters, see `lib/block_io/client.rb`.  
For more information, see https://block.io/api/simple/ruby.

## Contributing

1. Fork it ( https://github.com/BlockIo/gem-block-io/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
