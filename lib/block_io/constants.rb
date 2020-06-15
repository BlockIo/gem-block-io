module BlockIo

  WITHDRAW_METHODS = ["withdraw", "withdraw_from_address", "withdraw_from_addresses", "withdraw_from_label", "withdraw_from_labels"].inject({}){|h,v| h[v] = true; h}.freeze
  SWEEP_METHODS = ["sweep_from_address"].inject({}){|h,v| h[v] = true; h}.freeze
  
end
