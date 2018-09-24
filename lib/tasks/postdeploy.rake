desc 'Postdeploy task for setting up Heroku review apps'
task :postdeploy => ['db:reset', 'db:mongoid:create_indexes'] do
  Rails.application.eager_load!

  source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/gb-persons-with-significant-control-snapshot-sample-1k.txt"

  PscImportTask.new(open(source).readlines, '2016-12-06 06:15:37').call

  source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/eiti-data.txt"

  Rake::Task['eiti:import'].invoke(source)

  Entity.import(force: true)
end
