namespace :psc do
  desc 'Import PSC data from source (URL or path)'
  task :import, [:source] => ['db:reset'] do |_task, args|
    importer = PscImporter.new

    open(args.source) do |file|
      documents = importer.parse(file)

      Entity.collection.insert_many(documents)
    end
  end
end
