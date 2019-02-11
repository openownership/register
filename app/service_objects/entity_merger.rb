class EntityMerger
  PROTECTED_FIELDS = %w[_id type identifiers updated_at].freeze

  def initialize(entity_to_remove, entity_to_keep)
    @to_remove = entity_to_remove
    @to_keep = entity_to_keep
    @merged = false
  end

  def call
    raise 'Trying to merge the same entity' if @to_remove == @to_keep
    raise 'Already merged' if @merged

    check_types
    check_for_potential_bad_merge
    merge_fields_if_empty
    merge_identifiers
    update_references!
    delete_entity_to_remove_from_search

    @to_remove.destroy!
    @to_keep.save!

    reindex_entity_to_keep_for_search

    @merged = true

    @to_keep
  end

  private

  def check_types
    raise "to_remove entity type '#{@to_remove.type}' does not match to_keep entity type '#{@to_keep.type}' - cannot merge" unless @to_remove.type == @to_keep.type
  end

  def check_for_potential_bad_merge
    # We have a potentially bad merge if the entities have *differing* OC identifiers.
    # This is because we have no way of saying for sure that those two entities
    # can/should be merged and so we should err on the side of caution here.
    to_remove_oc_identifier = @to_remove.oc_identifier
    to_keep_oc_identifier = @to_keep.oc_identifier
    if to_remove_oc_identifier.present? &&
       to_keep_oc_identifier.present? &&
       to_remove_oc_identifier != to_keep_oc_identifier
      raise PotentiallyBadEntityMergeDetectedAndStopped, 'differing OC identifiers detected'
    end
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
  rescue Elasticsearch::Transport::Transport::Errors::NotFound => ex
    Rails.logger.warn "Entity merger failed to delete entity from ES because it was not found in the index - ID: #{@to_remove.id}; name: #{@to_remove.name}; error message: #{ex.message}"
  end

  def reindex_entity_to_keep_for_search
    IndexEntityService.new(@to_keep).index
  end
end

class PotentiallyBadEntityMergeDetectedAndStopped < StandardError
end
