desc 'Postdeploy task for setting up Heroku review apps'
task :postdeploy => ['db:reset', 'db:mongoid:create_indexes'] do
  Rails.application.eager_load!
  DevelopmentDataLoader.new.call
end

desc 'Task for setting up data used for the postdeploy task'
task :generate_postdeploy_data => ['db:reset', 'db:mongoid:create_indexes'] do
  Rails.application.eager_load!
  DevelopmentDataCreator.new.call
  DevelopmentDataDumper.new.call
end
