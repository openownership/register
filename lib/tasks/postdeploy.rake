desc 'Postdeploy task for setting up Heroku review apps'
task :postdeploy => ['db:reset', 'db:mongoid:create_indexes'] do
  source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/gb-persons-with-significant-control-snapshot-sample-1k.txt"

  Rake::Task['psc:import'].invoke(source, '2016-12-06 06:15:37')

  source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/eiti-data.txt"

  Rake::Task['eiti:import'].invoke(source)

  Entity.import(force: true)

  Rake::Task['db:seed'].invoke
end
