namespace :export do
  desc 'Export all data'
  task :all => ['export:entities', 'export:relationships']

  desc 'Export entities'
  task :entities => :environment do
    ExportToS3.new(ModelExport.new(Entity)).call
  end

  desc 'Export relationships'
  task :relationships => :environment do
    ExportToS3.new(ModelExport.new(Relationship)).call
  end
end
