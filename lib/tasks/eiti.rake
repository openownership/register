namespace :eiti do
  desc 'Import EITI data from source (URL or path)'
  task :import, [:source] => [:environment] do |_task, args|
    Rails.application.eager_load!

    importer = EitiImporter.new

    open(args.source) do |index_file|
      index_file.each_line do |line|
        source = JSON.parse(line, symbolize_names: true)

        open(source.fetch(:url)) do |source_file|
          importer.parse(source_file, jurisdiction_code: source[:jurisdiction_code], document_id: source[:document_id])
        end
      end
    end
  end
end
