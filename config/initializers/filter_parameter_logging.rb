# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :calculator, :validated_inputs, :calculation_snapshot, :property_price, :tax_assessment,
  :loan_principal, :own_contribution, :starting_cash, :reserve, :annual_interest_rate,
  :monthly_charges, :reservation, :schedule, :costs, :components, :own_inflows
]
