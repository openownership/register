namespace :migrations do
  desc "standardises identifiers for entities and relationships from submissions"
  task :reformat_submitted_identifiers => :environment do
    Submissions::Relationship.each do |submission_relationship|
      relationship = Relationship.where(_id: submission_relationship.id).first
      next unless relationship

      new_relationship = relationship.clone
      new_relationship.id = {
        'submission_id' => submission_relationship.submission.id,
        'relationship_id' => submission_relationship.id,
      }
      p "Creating Relationship #{new_relationship.id}"
      new_relationship.save!
      p "Removing Relationship #{relationship.id}"
      relationship.destroy!
    end

    Submissions::Entity.each do |submission_entity|
      entity = Entity.where(identifiers: submission_entity.id).first
      next unless entity

      entity.update_attribute(
        :identifiers,
        [
          {
            'submission_id' => submission_entity.submission.id,
            'entity_id' => submission_entity.id,
          },
        ],
      )
      p "Updating Entity #{entity.id}"
    end
  end
end
