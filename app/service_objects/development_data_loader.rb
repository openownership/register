class DevelopmentDataLoader
  def initialize
    @tmp_dir = Rails.root.join('tmp', 'dev-data', 'generated')
    @s3_adapter = Rails.application.config.s3_adapter.new(
      region: 'eu-west-1',
      access_key_id: ENV['DEV_DATA_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['DEV_DATA_AWS_SECRET_ACCESS_KEY'],
    )
  end

  def call
    FileUtils.mkdir_p @tmp_dir
    DevelopmentDataHelper::MODELS.each do |klass|
      file = klass.name.tableize
      data = File.read(download_from_s3_to_tmp("#{file}.json"))
      JSON.parse(data).each do |instance_data|
        if klass == User
          # We have to manually set the password and confirmed_at for users, devise
          # won't dump it
          instance_data[:confirmed_at] = Time.zone.now
          instance_data[:password] = ENV.fetch('ADMIN_BASIC_AUTH').split(":").last
        end

        # Mongo doesn't mongoize $oid fields outside of foreign keys and normal id
        # fields so we need to do it ourselves for identifiers and ids which come from
        # submissions
        if klass == Entity
          instance_data['identifiers'].each do |identifier|
            next unless identifier.is_a?(Hash)

            identifier.each do |key, value|
              identifier[key] = BSON::ObjectId.from_string(value['$oid']) if value['$oid']
            end
          end
        end

        if klass == Relationship && instance_data['_id'].is_a?(Hash)
          instance_data['_id'].each do |key, value|
            instance_data['_id'][key] = BSON::ObjectId.from_string(value['$oid']) if value['$oid']
          end
        end

        klass.create!(instance_data)
      end
    end

    Entity.import(force: true)
  end

  private

  attr_reader :s3_adapter

  def download_from_s3_to_tmp(filename)
    tmp_file = File.join(@tmp_dir, filename)
    FileUtils.mkdir_p File.dirname(tmp_file) # Sometimes we have new sub-dirs
    s3_adapter.download_from_s3(
      s3_bucket: ENV['DEV_DATA_S3_BUCKET_NAME'],
      s3_path: "generated/#{filename}",
      local_path: tmp_file
     )
    tmp_file
  end
end
