# BlockIo

This Ruby Gem is the official reference client for the Block.io's infrastructure APIs. To use this, you will need the Dogecoin, Bitcoin, or Litecoin API key(s) from <a href="https://block.io" target="_blank">Block.io</a>. Go ahead, sign up :)

## Installation

Add this line to your application's Gemfile:

    gem 'block_io'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install block_io

## Changelog
*06/09/21*: Version 3.0.1 implements use of dynamic decryption algorithms.
*04/14/21*: BREAKING CHANGES. Version 3.0.0. Remove support for Ruby < 2.4.0, and Windows. Behavior and interfaces have changed. By upgrading you'll need to revise your code and tests.

## Important Notes
* This gem depends on the bitcoinrb gem. By using this gem, your application will load the bitcoinrb gem as well with the Bitcoin namespace. It may conflict with another gem using the same namespace.  
* Transaction endpoints are updated as of v3.0.0.
* See the examples/ folder for basic examples.
* Be careful to test thoroughly before production.  
* Use of this software is subject to its LICENSE.  

## Usage

It's super easy to get started. In your Ruby shell ($ irb), for example, do this:

    require 'block_io'
    blockio = BlockIo::Client.new(:api_key => "API KEY", :pin => "SECRET PIN")    

If you do not have your PIN, or just wish to use your private key backup(s) directly, do this instead:

    blockio = BlockIo::Client.new(:api_key => "API KEY")
    blockio.get_balance
    blockio.prepare_transaction(..., :keys => [BlockIo::Key.from_wif("PRIVATE_KEY_BACKUP_IN_WIF").private_key_hex])    

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
