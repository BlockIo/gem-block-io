# constants for Block.io

module BlockIo

  class Constants

    PRIVKEY_VERSIONS = {
      'BTC' => '80',
      'BTCTEST' => 'ef',
      'DOGE' => '9e',
      'DOGETEST' => 'f1',
      'LTC' => 'b0',
      'LTCTEST' => 'ef'
    }

    ADDRESS_VERSIONS = {
      'BTC' =>  {:pk => '00', :p2sh => '05'},
      'BTCTEST' => {:pk => '6f', :p2sh => 'c4'},
      'DOGE' => {:pk => '1e', :p2sh => '16'},
      'DOGETEST' => {:pk => '71', :p2sh => 'c4'},
      'LTC' => {:pk => '30', :p2sh => '05'},
      'LTCTEST' => {:pk => '6f', :p2sh => 'c4'}
    }

  end

end
