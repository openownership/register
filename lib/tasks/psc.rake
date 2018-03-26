namespace :psc do
  desc 'Import PSC data from source (URL or path)'
  task :import, [:source, :retrieved_at] => [:environment] do |_task, args|
    Rails.application.eager_load!

    PscImportTask.new(args.source, args.retrieved_at).call
  end

  desc 'Trigger a PSC data import using the latest source data snapshot files'
  task :trigger => :environment do
    PscImportTrigger.new.call
  end
end
