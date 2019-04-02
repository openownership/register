desc 'Postdeploy task for setting up Heroku review apps'
task :postdeploy => ['db:reset', 'db:mongoid:create_indexes'] do
  Rails.application.eager_load!

  dumped_models.each do |klass|
    file = klass.name.tableize
    data = File.read(Rails.root.join('db', 'data', 'generated', "#{file}.json"))
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

desc 'Task for setting up data used for the postdeploy task'
task :generate_postdeploy_data => ['db:reset', 'db:mongoid:create_indexes'] do
  Rails.application.eager_load!

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

  dumped_models.each do |klass|
    file = klass.name.tableize
    File.open(Rails.root.join('db', 'data', 'generated', "#{file}.json"), 'w') do |f|
      f.write JSON.pretty_generate(klass.all.as_json)
    end
  end
end

def dumped_models
  [
    User,
    Submissions::Submission,
    Submissions::Entity,
    Submissions::Relationship,
    Entity,
    Relationship,
    Statement,
  ]
end
