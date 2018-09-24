namespace :psc do
  desc 'Trigger a PSC data import in a background job using the latest source data snapshot files'
  task :trigger, %i[chunk_size] => :environment do |_task, args|
    chunk_size = (args.chunk_size || 100).to_i
    PscImportTrigger.new.call chunk_size
  end
end
