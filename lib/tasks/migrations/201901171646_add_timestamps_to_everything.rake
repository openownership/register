namespace :migrations do
  desc "backfill timestamps on models as best we can from other data"
  task :timestamp_everything => :environment do
    # Models with a standard id field can infer created_at from that because it's
    # embedded in mongodb ids, but we don't have anything reliable for
    # updated_at.
    # Note: we can't infer created_at from Relationship or Statement ids because
    # they don't have ObjectIds like other models, we've overriden _id to be a
    # hash of other info, and there's nothing else reliable to infer them from.
    models = [
      Entity,
      User,
      Submissions::Entity,
      Submissions::Relationship,
    ]
    models.each do |klass|
      Rails.logger.info "Timestamping #{klass.name.pluralize}"
      klass.each do |record|
        begin
          record.timeless.update_attribute(:created_at, record.id.generation_time)
        rescue StandardError => e
          Rails.logger.warn "Error timestamping #{klass.name} with id: #{record.id}: #{e.message}"
        end
      end
    end

    # Submissions have a created_at already, and they have a changed_at which is
    # quite a good approximation for updated_at (at the time of writing)
    Rails.logger.info "Timestamping Submissions"
    Submissions::Submission.each do |submission|
      begin
        submission.timeless.update_attribute(:updated_at, submission.changed_at)
      rescue StandardError => e
        Rails.logger.warn "Error timestamping Submission with id: #{submission.id}: #{e.message}"
      end
    end
  end
end
