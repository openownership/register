Rails.application.config.oc_api = Hashie::Mash.new(
  token: ENV.fetch('OPENCORPORATES_API_TOKEN'),
  token_protected: ENV.fetch('OPENCORPORATES_API_TOKEN_PROTECTED'),
)
