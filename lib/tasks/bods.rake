namespace :bods do
  desc 'Trigger a BODS data import in a background job'
  arguments = %i[download_url schemes chunk_size format]
  task :trigger, arguments => :environment do |_task, args|
    raise 'Download url and company number schemes array are required arguments' if args.download_url.blank? || args.schemes.blank?
    jsonl = args.format == 'jsonl'
    chunk_size = (args.chunk_size || 100).to_i
    BodsImportTrigger.new(args.download_url, args.schemes, chunk_size, jsonl: jsonl).call
  end
end
