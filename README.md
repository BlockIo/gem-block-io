# BlockIo

This Ruby Gem is the official reference client for the Block.io payments API. To use this, you will need the Dogecoin, Bitcoin, or \
Litecoin API key(s) from <a href="https://block.io" target="_blank">Block.io</a>. Go ahead, sign up :)

## Installation

Add this line to your application's Gemfile:

    gem 'block_io'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install block_io

## Usage

It's super easy to get started. In your Ruby shell ($ irb), for example, do this:

    require 'block_io'
    BlockIo.set_options :api_key => 'API KEY', :pin => 'SECRET PIN'
     
And you're good to go:

    BlockIo.get_new_address
    BlockIo.get_my_addresses

For more information, see https://block.io/api

## Contributing

1. Fork it ( https://github.com/[my-github-username]/block_io/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
