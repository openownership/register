class NonDestructivePeopleMerger
  def initialize(person_to_merge, person_to_keep)
    @to_merge = person_to_merge
    @to_keep = person_to_keep
  end

  def call
    raise 'Trying to merge the same entity' if @to_merge == @to_keep

    check_types
    delete_entity_to_merge_from_search
    @to_keep.merged_entities << @to_merge

    @to_keep
  end

  private

  def check_types
    raise "to_merge is not a person" unless @to_merge.natural_person?
    raise "to_keep is not a person" unless @to_keep.natural_person?
  end

  def delete_entity_to_merge_from_search
    IndexEntityService.new(@to_merge).delete
  rescue Elasticsearch::Transport::Transport::Errors::NotFound => ex
    Rails.logger.warn "Entity merger failed to delete entity from ES because it was not found in the index - ID: #{@to_merge.id}; name: #{@to_merge.name}; error message: #{ex.message}"
  end
end
