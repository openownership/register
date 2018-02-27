class IndexEntityService
  def initialize(entity)
    @entity = entity
  end

  def index
    @entity.__elasticsearch__.index_document
  end

  def delete
    @entity.__elasticsearch__.delete_document
  end
end
