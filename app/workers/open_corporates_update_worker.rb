class OpenCorporatesUpdateWorker
  include Sidekiq::Worker

  def perform(entity_id)
    entity = Entity.find(entity_id)
    EntityResolver.new.resolve!(entity)
    if entity.oc_updated_at_changed?
      entity.upsert_and_merge_duplicates!
      IndexEntityService.new(entity).index
    else
      entity.touch(:last_resolved_at)
    end
  rescue PotentiallyBadEntityMergeDetectedAndStopped => ex
    log_message = "#{self.class.name} Failed to handle a required entity " \
                  "merge as a potentially bad merge has been detected " \
                  "and stopped: #{ex.message} - will not complete the " \
                  "update of #{entity.id}"
    Rails.logger.warn log_message
  end
end
