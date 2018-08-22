namespace :migrations do
  desc "Fixes cases where the ordering of keys for the OC identifier was reversed"
  task :fix_oc_identifiers_ordering => :environment do
    results = {
      has_both_ids: {
        total: 0,
        ids_mismatched: Set.new,
        dup_detected_on_upsert: Set.new,
        merged: 0,
        failed_merge: Set.new,
        reresolved: Set.new,
        fixed: 0,
      },
      just_bad_id: {
        total: 0,
        dup_detected_on_upsert: Set.new,
        merged: 0,
        failed_merge: Set.new,
        reresolved: Set.new,
        fixed: 0,
      },
    }

    deleted = Set.new

    total = Entity.count

    oc_keys_set = %w[jurisdiction_code company_number].to_set.freeze

    index = 0

    Entity.all.each do |entity|
      index += 1
      Rails.logger.info "#{index} out of #{total} entities processed" if (index % 100_000).zero?

      e_id = entity._id.to_s

      if deleted.include? e_id
        Rails.logger.info "Skipping processing of entity #{e_id} as it has been deleted earlier in this migration"
        next
      end

      oc_identifiers = entity.identifiers.select do |i|
        i.keys.to_set == oc_keys_set
      end

      if oc_identifiers.size > 2
        Rails.logger.info "More than 2 OC identifiers were found for entity '#{e_id}' – OC identifiers = #{oc_identifiers}"
      end

      case oc_identifiers.size
      when 2
        FixOCIdentifiersOrderingHelper.handle_two_oc_identifiers(
          entity,
          oc_identifiers,
          results[:has_both_ids],
          deleted,
        )
      when 1
        FixOCIdentifiersOrderingHelper.handle_one_oc_identifier(
          entity,
          oc_identifiers.first,
          results[:just_bad_id],
          deleted,
        )
      end
    end

    Rails.logger.info "migrations:fix_oc_identifiers_ordering results = #{results.to_json}"
  end
end

module FixOCIdentifiersOrderingHelper
  def self.entity_resolver
    @entity_resolver ||= EntityResolver.new
  end

  def self.handle_two_oc_identifiers(entity, identifiers_found, results, deleted)
    results[:total] += 1

    e_id = entity._id.to_s

    if identifiers_found.first != identifiers_found.second
      results[:ids_mismatched].add(e_id)

      Rails.logger.info "Entity #{e_id} was found to have two *mismatched* OC identifiers (i.e. with different company numbers) - won't attempt to fix this entity in this migration."
    else
      FixOCIdentifiersOrderingHelper.try_fix!(
        entity,
        {
          'jurisdiction_code' => identifiers_found.first['jurisdiction_code'],
          'company_number' => identifiers_found.first['company_number'],
        },
        results,
        deleted,
      )
    end
  end

  def self.handle_one_oc_identifier(entity, identifier, results, deleted)
    return if identifier.keys.first != 'company_number'

    results[:total] += 1

    FixOCIdentifiersOrderingHelper.try_fix!(
      entity,
      {
        'jurisdiction_code' => identifier['jurisdiction_code'],
        'company_number' => identifier['company_number'],
      },
      results,
      deleted,
    )
  end

  def self.try_fix!(entity, actual_oc_identifier, results, deleted)
    # IMPORTANT: currently, `Entity#upsert` doesn't remove identifiers!
    # First fix identifiers and upsert to catch any dups that need merging
    adjust_identifiers(entity, actual_oc_identifier)
    entity.upsert

    # Then fix identifiers again and save to remove the bad OC identifier
    adjust_identifiers(entity, actual_oc_identifier)
    entity.save!

    results[:fixed] += 1
  rescue DuplicateEntitiesDetected => ex
    results[:dup_detected_on_upsert].add(entity._id.to_s)

    success = handle_duplicate_entities!(
      entity,
      ex.criteria,
      results,
      deleted,
    )

    retry if success
  end

  def self.adjust_identifiers(entity, actual_oc_identifier)
    # `Array#delete` deletes all instances of that Hash, regardless of key order, e.g.:
    # > [{a:1,b:2},{b:2,a:1},{a:2,b:1}].delete({a:1,b:2})
    # => {:b=>2, :a=>1}
    identifiers = entity.identifiers.dup
    identifiers.delete(actual_oc_identifier)
    identifiers.push(actual_oc_identifier)
    entity.identifiers = identifiers
  end

  def self.handle_duplicate_entities!(original_entity, criteria, results, deleted)
    to_keep = original_entity
    to_remove = criteria.entries.find { |e| e != to_keep }

    Rails.logger.info "Duplicate entities detected for selector: #{criteria.selector} - attempting to merge entity A into entity B. A = ID: #{to_remove._id}, name: #{to_remove.name}, identifiers: #{to_remove.identifiers}; B = ID: #{to_keep._id}, name: #{to_keep.name}, identifiers: #{to_keep.identifiers};"

    EntityMerger.new(to_remove, to_keep).call

    # If both entities don't have the exact same name (case-insensitive), then
    # we need to re-resolve this merged entity in order to fetch the latest
    # metadata.
    if to_keep.name.casecmp(to_remove.name) != 0
      entity_resolver.resolve!(to_keep)
      results[:reresolved].add(to_keep._id.to_s)
    end

    results[:merged] += 1

    deleted.add(to_remove._id.to_s)

    true
  rescue PotentiallyBadEntityMergeDetectedAndStopped => ex
    e_id = entity._id.to_s

    Rails.logger.warn "Failed to handle an entity merge - a potentially bad merge has been detected and stopped: #{ex.message} - triggered by trying to fix entity #{e_id}"

    results[:failed_merge].add(e_id)

    false
  end
end
