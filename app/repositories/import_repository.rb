class ImportRepository
  def all_for_entity(entity)
    Import.where('id' => { '$in' => import_ids_for_entity(entity) })
  end

  def data_source_ids_for_entity(entity)
    Import.where('id' => { '$in' => import_ids_for_entity(entity) }).distinct(:data_source_id)
  end

  private

  def import_ids_for_entity(entity)
    raw_data_provenance_repository.import_ids_for_entity(entity)
  end

  def raw_data_provenance_repository
    Rails.application.config.raw_data_provenance_repository
  end
end
