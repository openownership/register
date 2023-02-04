class RawDataProvenanceRepository
  def import_ids_for_entity(entity)
    RawDataProvenance.where(
      'entity_or_relationship_id' => { '$in' => entity.all_ids },
      'entity_or_relationship_type' => 'Entity',
    ).distinct(:import_id)
  end

  def raw_data_record_ids_for_entity(entity)
    RawDataProvenance.where(
      'entity_or_relationship_id' => { '$in' => entity.all_ids },
      'entity_or_relationship_type' => 'Entity',
    ).pluck(:raw_data_record_ids).flatten.compact
  end
end
