namespace :dk do
  desc 'Trigger a Denmark CVR data import in a background job'
  task :trigger, %i[chunk_size] => :environment do |_task, args|
    chunk_size = (args.chunk_size || 100).to_i
    data_source = DataSource.find 'dk-cvr-register'
    DkImportTrigger.new.call data_source, chunk_size
  end
end
