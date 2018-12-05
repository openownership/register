namespace :dk do
  desc 'Trigger a Denmark CVR data import in a background job'
  task :trigger, %i[chunk_size] => :environment do |_task, args|
    chunk_size = (args.chunk_size || 100).to_i
    DkImportTrigger.new.call chunk_size
  end
end
