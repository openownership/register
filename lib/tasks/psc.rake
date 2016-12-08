namespace :psc do
  desc 'Import PSC data from source (URL or path)'
  task :import, [:source] => ['db:reset'] do |_task, args|
    importer = PscImporter.new

    open(args.source) do |file|
      importer.parse(file)
    end

    Entity.collection.insert_many(importer.entities)

    Relationship.collection.insert_many(importer.relationships)

    Entity.import(force: true)
  end
end
