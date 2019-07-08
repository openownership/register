class NonDestructivePeopleMerger
  def initialize(person_to_merge, person_to_keep)
    @to_merge = person_to_merge
    @to_keep = person_to_keep
  end

  def call
    raise 'Trying to merge the same entity' if @to_merge == @to_keep

    check_types
    delete_entity_to_merge_from_search
    recursively_merge_merged_entities
    old_master = @to_merge.master_entity
    @to_keep.merged_entities << @to_merge
    old_master.reset_counters(:merged_entities) if old_master.present?

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

  def recursively_merge_merged_entities
    return if @to_merge.merged_entities.empty?

    Rails.logger.warn "[#{self.class.name}] recursively merging merged entities from #{@to_merge.id} (#{@to_merge.name}) into #{@to_keep.id}"
    @to_merge.merged_entities.each do |e|
      NonDestructivePeopleMerger.new(e, @to_keep).call
    end
    @to_merge.merged_entities = []
    @to_merge.reset_counters(:merged_entities)
  end
end
