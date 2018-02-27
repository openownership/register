class EntityMerger
  PROTECTED_FIELDS = %w(_id type identifiers).freeze

  def initialize(entity_to_remove, entity_to_keep)
    @to_remove = entity_to_remove
    @to_keep = entity_to_keep
    @merged = false
  end

  def call
    raise 'Trying to merge the same entity' if @to_remove == @to_keep
    raise 'Already merged' if @merged

    check_types
    merge_fields_if_empty
    merge_identifiers
    update_references!
    delete_entity_to_remove_from_search

    @to_remove.destroy!
    @to_keep.save!

    reindex_entity_to_keep_for_search

    @merged = true
  end

  private

  def check_types
    raise "to_remove entity type '#{@to_remove.type}' does not match to_keep entity type '#{@to_keep.type}' - cannot merge" unless @to_remove.type == @to_keep.type
  end

  def merge_fields_if_empty
    (Entity.fields.keys - PROTECTED_FIELDS).each do |k|
      @to_keep[k] = @to_remove[k] if @to_keep[k].blank?
    end
  end

  def merge_identifiers
    @to_keep.identifiers.concat @to_remove.identifiers
  end

  def update_references!
    Relationship.where(source: @to_remove).update_all(source_id: @to_keep._id)
    Relationship.where(target: @to_remove).update_all(target_id: @to_keep._id)
    Statement.where(entity: @to_remove).update_all(entity_id: @to_keep._id)
  end

  def delete_entity_to_remove_from_search
    IndexEntityService.new(@to_remove).delete
  end

  def reindex_entity_to_keep_for_search
    IndexEntityService.new(@to_keep).index
  end
end
