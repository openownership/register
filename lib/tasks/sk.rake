namespace :sk do
  desc 'Trigger a Slovakia data import in a background job'
  task :trigger, %i[chunk_size] => :environment do |_task, args|
    chunk_size = (args.chunk_size || 100).to_i
    data_source = DataSource.find 'slovakia-public-sector-partners-register-register-partnerov-verejneho-sektora'
    SkImportTrigger.new.call data_source, chunk_size
  end
end
