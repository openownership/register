class DataSourceLoader
  def call
    folder = Rails.root.join('content', 'data_sources')
    Dir.chdir(folder)
    data_source_folders = Dir.glob('*').select { |f| File.directory? f }

    data_source_folders.each do |data_source_folder|
      Dir.chdir(folder.join(data_source_folder))
      metadata = YAML.load_file('_metadata.yml')
      data_source = DataSource.find_or_initialize_by(slugs: metadata['slugs'])
      data_source.assign_attributes(metadata)

      overview_files = Dir.glob('overview.*.md')
      if overview_files.any?
        overview_translations = {}
        overview_files.each do |filename|
          locale = filename.split('.')[1]
          overview_translations[locale] = File.read filename
        end
        data_source.overview_translations = overview_translations
      end

      availability_files = Dir.glob('data_availability.*.md')
      if availability_files.any?
        availability_translations = {}
        availability_files.each do |filename|
          locale = filename.split('.')[1]
          availability_translations[locale] = File.read filename
        end
        data_source.data_availability_translations = availability_translations
      end

      data_source.save!
    end
  end
end
