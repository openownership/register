class DevelopmentDataCreator
  def call
    FactoryGirl.create_list(:draft_submission, 3)
    FactoryGirl.create_list(:submitted_submission, 3)
    FactoryGirl.create_list(:approved_submission, 3)

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

    ua_data = Rails.root.join('db', 'data', 'ua_seed_data.jsonl')
    FactoryGirl.create(:ua_data_source)
    Rake.application['ua:import'].invoke(ua_data, Date.current.to_s)

    psc_data_source = FactoryGirl.create(:psc_data_source)
    uk_import = Import.create!(data_source: psc_data_source)
    uk_data = Rails.root.join('db', 'data', 'gb-persons-with-significant-control-snapshot-sample-1k.txt')
    records = open(uk_data).readlines.map do |line|
      data = JSON.parse(line)
      etag = data['data']['etag']
      FactoryGirl.create(:raw_data_record, raw_data: line, etag: etag, imports: [uk_import])
    end
    retrieved_at = Time.zone.parse('2016-12-06 06:15:37')
    importer = PscImporter.new
    importer.import = uk_import
    importer.retrieved_at = retrieved_at
    importer.process_records(records)

    eiti_data = Rails.root.join('db', 'data', 'eiti-data.txt')
    File.readlines(eiti_data).each do |line|
      data = JSON.parse(line)
      country_name = data['document_id'].gsub('EITI Structured Data - ', '')
      FactoryGirl.create(
        :eiti_data_source,
        name: "EITI pilot data - #{country_name}",
        url: data['url'],
        document_id: data['document_id'],
      )
    end
    Rake::Task['eiti:import'].invoke(eiti_data)

    Entity.import(force: true)

    NaturalPersonsDuplicatesMerger.new.run
  end
end
