namespace :bods do
  desc 'Trigger a BODS data import in a background job'
  task :trigger => :environment do
    BodsImportTrigger.new.call
  end
end
