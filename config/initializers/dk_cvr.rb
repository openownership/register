Rails.application.config.dk_cvr = Hashie::Mash.new(
  username: ENV.fetch('DK_CVR_USERNAME'),
  password: ENV.fetch('DK_CVR_PASSWORD'),
)
