class RawDataRecordRepository
  def raw_record_count_for_entity(entity)
    RawDataRecord.all_for_entity(entity).size
  end

  def all_for_entity_with_imports(entity)
    RawDataRecord.all_for_entity(entity).includes(:imports).order_by(updated_at: :desc, created_at: :desc)
  end

  def newest_for_entity(entity)
    RawDataRecord.newest_for_entity(entity)
  end

  def oldest_for_entity(entity)
    RawDataRecord.oldest_for_entity(entity)
  end
end
