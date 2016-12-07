desc 'Postdeploy task for setting up Heroku review apps'
task :postdeploy do
  source = "http://#{ENV.fetch('BUCKETEER_BUCKET_NAME')}.s3.amazonaws.com/public/gb-persons-with-significant-control-snapshot-sample-1k.txt"

  Rake::Task['psc:import'].invoke(source)
end
