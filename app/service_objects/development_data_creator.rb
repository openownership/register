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
    Rake.application['ua:import'].invoke(ua_data, Date.current.to_s)

    uk_data = Rails.root.join('db', 'data', 'gb-persons-with-significant-control-snapshot-sample-1k.txt')
    records = open(uk_data).readlines.map do |line|
      JSON.parse(line, symbolize_names: true, object_class: OpenStruct)
    end
    retrieved_at = Time.zone.parse('2016-12-06 06:15:37')
    PscImportTask.new(records, retrieved_at).call

    eiti_data = Rails.root.join('db', 'data', 'eiti-data.txt')
    Rake::Task['eiti:import'].invoke(eiti_data)

    Entity.import(force: true)

    NaturalPersonsDuplicatesMerger.new.run
  end
end
