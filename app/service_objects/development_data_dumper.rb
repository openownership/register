class DevelopmentDataDumper
  def initialize
    @tmp_dir = Rails.root.join('tmp', 'dev-data', 'generated')
    @s3_client = Aws::S3::Client.new(
      region: 'eu-west-1',
      access_key_id: ENV['DEV_DATA_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['DEV_DATA_AWS_SECRET_ACCESS_KEY'],
    )
  end

  def call
    FileUtils.mkdir_p @tmp_dir
    DevelopmentDataHelper::MODELS.each do |klass|
      filename = "#{klass.name.tableize}.json"
      tmp_file = File.join(@tmp_dir, filename)
      FileUtils.mkdir_p File.dirname(tmp_file) # Sometimes we have new sub-dirs
      File.open(tmp_file, 'w') do |f|
        f.write JSON.pretty_generate(klass.all.as_json)
      end
      upload_to_s3(tmp_file, filename)
    end
  end

  private

  def upload_to_s3(tmp_file, filename)
    s3 = Aws::S3::Object.new(
      ENV['DEV_DATA_S3_BUCKET_NAME'],
      "generated/#{filename}",
      client: @s3_client,
    )
    s3.upload_file(tmp_file)
  end
end
