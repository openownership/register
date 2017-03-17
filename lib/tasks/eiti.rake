namespace :eiti do
  desc 'Import EITI data from source (URL or path)'
  task :import, [:source] => [:environment] do |_task, args|
    Rails.application.eager_load!

    importer = EitiImporter.new
    importer.source_name = 'EITI pilot data'

    open(args.source) do |index_file|
      index_file.each_line do |line|
        source = JSON.parse(line, symbolize_names: true)

        open(source.fetch(:url)) do |source_file|
          importer.source_jurisdiction_code = source[:jurisdiction_code]
          importer.document_id = source[:document_id]
          importer.retrieved_at = Time.zone.parse(source[:retrieved_at])
          importer.parse(source_file)
        end
      end
    end
  end
end
