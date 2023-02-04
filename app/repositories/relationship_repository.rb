class RelationshipRepository
  def build_relationship(**args)
    Relationship.new(**args)
  end

  def relationships_for_target_id(id)
    Relationship.includes(:target, :source).where(target_id: id)
  end

  def relationships_for_source_id(id)
    Relationship.includes(:target, :source, :raw_data_provenances).where(source_id: id)
  end

  def relationships_for_source_ids(ids)
    Relationship.includes(:target, :source, :raw_data_provenances).where(source_id: ids)
  end
end
