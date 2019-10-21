class IndexEntityService
  def initialize(entity)
    @entity = entity
  end

  def index
    return if @entity.master_entity.present?

    @entity.__elasticsearch__.index_document
  end

  def delete
    @entity.__elasticsearch__.delete_document
  end
end
