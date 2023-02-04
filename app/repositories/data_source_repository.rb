class DataSourceRepository
  def all
    DataSource.all
  end

  def find(id)
    DataSource.find(id)
  end

  def where_overview_present
    DataSource.where(:overview.ne => nil)
  end

  def data_source_names_for_entity(entity)
    DataSource.where('id' => { '$in' => data_source_ids_for_entity(entity) }).pluck(:name)
  end

  def data_sources_for_entity(entity)
    DataSource.where('id' => { '$in' => data_source_ids_for_entity(entity) })
  end

  private

  def data_source_ids_for_entity(entity)
    import_repository.data_source_ids_for_entity(entity)
  end

  def import_repository
    Rails.application.config.import_repository
  end
end
