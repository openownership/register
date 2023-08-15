class DataSourceRepository
  def all
    path = File.join(File.dirname(__FILE__), 'datasources.json')
    sources = JSON.parse(File.read(path), symbolize_names: true)
    
    sources[:datasources].map { |source|
      DataSource.new source.merge(id: source[:'_id'][:'$oid'])
    }
  end

  def find(id)
    find_many([id])[0]
  end

  def find_many(ids)
    all.filter { |data_source| ids.include? data_source.id }
  end

  def where_overview_present
    all.filter { |data_source| data_source.overview.present? }
  end

  def data_source_names_for_entity(entity)
    ["UK PSC Register"] # TODO: generate from sources of entity (or identifiers)
  end

  def all_for_entity(entity)
    data_source_names = data_source_names_for_entity(entity)
    all.filter { |data_source| data_source_names.include? data_source.name }
  end
end
