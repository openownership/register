class IndexEntityService
  def initialize(entity)
    @entity = entity
  end

  def call
    @entity.__elasticsearch__.index_document
  end
end
