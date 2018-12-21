namespace :sk do
  desc 'Trigger a Slovakia data import in a background job'
  task :trigger, %i[chunk_size] => :environment do |_task, args|
    chunk_size = (args.chunk_size || 100).to_i
    SkImportTrigger.new.call chunk_size
  end
end
