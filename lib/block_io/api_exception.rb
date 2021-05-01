module BlockIo
  class APIException < Exception
    
    attr_reader :raw_data
    
    def set_raw_data(data)
      @raw_data = data
    end
  end
end

