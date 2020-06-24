module BlockIo

  WITHDRAW_METHODS = ["withdraw", "withdraw_from_address", "withdraw_from_addresses", "withdraw_from_label", "withdraw_from_labels",
                      "withdraw_from_dtrust_address", "withdraw_from_dtrust_addresses", "withdraw_from_dtrust_label", "withdraw_from_dtrust_labels"].inject({}){|h,v| h[v] = true; h}.freeze

  SWEEP_METHODS = ["sweep_from_address"].inject({}){|h,v| h[v] = true; h}.freeze

  FINALIZE_SIGNATURE_METHODS = ["sign_and_finalize_withdrawal", "sign_and_finalize_sweep"].inject({}){|h,v| h[v] = true; h}.freeze
  
end
