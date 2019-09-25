Aws.config[:credentials] = Aws::Credentials.new(
  ENV['BODS_EXPORT_AWS_ACCESS_KEY_ID'],
  ENV['BODS_EXPORT_AWS_SECRET_ACCESS_KEY'],
)
Aws.config[:region] = 'eu-west-1'
