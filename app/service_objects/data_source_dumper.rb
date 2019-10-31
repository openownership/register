class DataSourceDumper
  def call
    DataSource.all.each do |ds|
      folder = Rails.root.join('content', 'data_sources', ds.slug)
      FileUtils.mkdir_p folder
      metadata_file = folder.join('_metadata.yml')
      File.open(metadata_file, 'w') do |f|
        metadata = {
          'name' => ds.name,
          'slugs' => ds.slugs,
          'document_id' => ds.document_id,
          'timeline_url' => ds.timeline_url,
          'current_statistic_types' => ds.current_statistic_types,
          'types' => ds.types,
        }.compact
        f.write(metadata.to_yaml(indentation: 2))
      end

      unless ds.overview_translations.values.all(&:blank?)
        ds.overview_translations.each do |locale, content|
          overview_file = folder.join("overview.#{locale}.md")
          File.open(overview_file, 'w') do |f|
            f.write content
          end
        end
      end

      next if ds.data_availability_translations.all?(&:blank?)

      ds.data_availability_translations.each do |locale, content|
        availability_file = folder.join("data_availability.#{locale}.md")
        File.open(availability_file, 'w') do |f|
          f.write content
        end
      end
    end
  end
end
