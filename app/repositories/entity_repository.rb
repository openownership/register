class EntityRepository
  def find(id)
    Entity.find(id)
  end

  def find_or_unknown(id)
    if id.to_s.include?('statement') || id.to_s.include?(Entity::UNKNOWN_ID_MODIFIER)
      UnknownPersonsEntity.new(id: id)
    else
      find(id)
    end
  end

  def find_with_master_entity(id)
    Entity.includes(:master_entity).find(id)
  end

  def search(query:, aggs:)
    Entity.search(query: Search.query(search_params), aggs: Search.aggregations)
  end

  def count_legal_entities
    Entity.legal_entities.count
  end
end
