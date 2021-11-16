class DevelopmentDataCreator
  def initialize
    @tmp_dir = Rails.root.join('tmp', 'dev-data')
    @s3_adapter = Rails.application.config.s3_adapter.new(
      region: 'eu-west-1',
      access_key_id: ENV['DEV_DATA_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['DEV_DATA_AWS_SECRET_ACCESS_KEY'],
    )
  end

  def call
    FileUtils.mkdir_p @tmp_dir

    DataSourceLoader.new.call

    FactoryBot.create_list(:draft_submission, 3)
    FactoryBot.create_list(:submitted_submission, 3)
    FactoryBot.create_list(:approved_submission, 3)

    password = ENV.fetch('ADMIN_BASIC_AUTH').split(":").last
    ENV.fetch('DEFAULT_USERS').split(",").each do |email|
      User.create!(
        email: email,
        name: email.split("@").first,
        company_name: 'Open Ownership',
        position: 'N/A',
        password: password,
        confirmed_at: Time.zone.now,
      )
    end

    ua_data = download_from_s3_to_tmp('ua_seed_data.jsonl')
    importer = UaImporter.new(
      source_url: 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10',
      source_name: 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])',
      document_id: 'Ukraine EDR',
      retrieved_at: Time.zone.now,
    )
    importer.parse(File.open(ua_data))

    psc_data_source = DataSource.find('uk-psc-register')
    uk_import = Import.create!(data_source: psc_data_source)
    uk_data = download_from_s3_to_tmp('gb-persons-with-significant-control-snapshot-sample-1k.txt')
    records = open(uk_data).readlines.map do |line|
      data = JSON.parse(line)
      etag = data['data']['etag']
      FactoryBot.create(:raw_data_record, raw_data: line, etag: etag, imports: [uk_import])
    end
    retrieved_at = Time.zone.parse('2016-12-06 06:15:37')
    importer = PscImporter.new
    importer.import = uk_import
    importer.retrieved_at = retrieved_at
    importer.process_records(records)

    eiti_data = download_from_s3_to_tmp('eiti-data.txt')
    Rake::Task['eiti:import'].invoke(eiti_data)

    Entity.import(force: true)

    NaturalPersonsDuplicatesMerger.new.run
  end

  private

  attr_reader :s3_adapter

  def download_from_s3_to_tmp(filename)
    tmp_file = File.join(@tmp_dir, filename)
    s3_adapter.download_from_s3(s3_bucket: ENV['DEV_DATA_S3_BUCKET_NAME'], s3_path: filename, local_path: tmp_file)
    tmp_file
  end
end
