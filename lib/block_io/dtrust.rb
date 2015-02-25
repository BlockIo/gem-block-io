module BlockIo

  class DTrust

    def self.common_checks
      # throw exceptions if conditions are not satified
      raise Exception.new("This feature is only available for API V2") unless Vars.version == 2

    end

    def self.get_new_address(args = {})
      # get a new dTrust address
      # specify make_green=1 to make the address green (i.e., omit redeem script in response)

      common_checks

      # our public keys
      args[:keys] ||= []
      args[:public_keys] = args[:keys].map(&:public_key).join(',')
      args.delete(:keys)      
      args[:make_green] = args[:make_green].to_i if args.key?(:make_green)

      Helper.api_call(['get_new_dtrust_address', Helper.get_params(args)])

    end

    def self.get_my_addresses
      # get a list of all of our dTrust addresses

      common_checks

      Helper.api_call(['get_my_dtrust_addresses', ''])

    end

  end

end
