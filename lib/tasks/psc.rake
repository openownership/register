namespace :psc do
  desc 'Trigger a PSC data import in a background job using the latest source data snapshot files'
  task :trigger => :environment do
    PscImportTrigger.new.call
  end
end
