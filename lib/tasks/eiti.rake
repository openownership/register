require 'open-uri'

namespace :eiti do
  desc 'Import EITI data from source (URL or path)'
  task :import, [:source] => [:environment] do |_task, args|
    Rails.application.eager_load!

    lines = open(args.source).each_line

    Parallel.each(lines, in_processes: 5) do |line|
      puts line
      source = JSON.parse(line, symbolize_names: true)

      print '.'
      begin
        open(source.fetch(:url)) do |source_file|
          importer = EitiImporter.new
          importer.source_name = 'EITI pilot data'
          importer.source_jurisdiction_code = source[:jurisdiction_code]
          importer.document_id = source[:document_id]
          importer.retrieved_at = Time.zone.parse(source[:retrieved_at])
          importer.parse(source_file)
        end
      rescue # rubocop:disable Style/RescueStandardError
        puts "\nJurisdiction: '#{source[:jurisdiction_code]}', url: #{source[:url]} FAILED. Retrying..."
        retry
      end
    end
  end
end
