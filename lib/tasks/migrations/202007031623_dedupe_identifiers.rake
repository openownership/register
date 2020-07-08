namespace :migrations do
  desc "Removes duplicates from all entity identifiers"
  task :dedupe_identifiers => :environment do
    Entity.each do |entity|
      identifiers_before = entity.identifiers
      unique_identifiers = identifiers_before.uniq
      if unique_identifiers.count < identifiers_before.count
        entity.update_attribute('identifiers', unique_identifiers)
        Rails.logger.info "Removed #{identifiers_before.count - unique_identifiers.count} duplicate identifiers from entity: #{entity.id}"
      end
    end
  end
end
