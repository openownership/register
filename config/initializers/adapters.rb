require 'register_common/adapters/s3_adapter'
require 'register_common/structs/aws_credentials'

Rails.application.config.s3_adapter = RegisterCommon::Adapters::S3Adapter.new(
  credentials: RegisterCommon::Structs::AwsCredentials.new(
    ENV.fetch('BODS_EXPORT_AWS_REGION', 'eu-west-1'),
    ENV.fetch('BODS_EXPORT_AWS_ACCESS_KEY_ID'),
    ENV.fetch('BODS_EXPORT_AWS_SECRET_ACCESS_KEY')
  )
)
