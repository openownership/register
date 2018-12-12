desc 'Postdeploy task for setting up Heroku review apps'
task :postdeploy => ['db:reset', 'db:mongoid:create_indexes'] do
  Rails.application.eager_load!

  source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/gb-persons-with-significant-control-snapshot-sample-1k.txt"
  records = open(source).readlines.map do |line|
    JSON.parse(line, symbolize_names: true, object_class: OpenStruct)
  end
  retrieved_at = Time.zone.parse('2016-12-06 06:15:37')
  PscImportTask.new(records, retrieved_at).call

  # Temporarily disable EITI sample import as it's causing Heroku review app creation to time out.
  #
  # source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/eiti-data.txt"
  #
  # Rake::Task['eiti:import'].invoke(source)

  Entity.import(force: true)
end
