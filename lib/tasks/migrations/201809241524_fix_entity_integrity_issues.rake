namespace :migrations do
  desc "Attempts to fix some entity integrity issues around multiple company numbers, badly merged entities, etc."
  task :fix_entity_integrity_issues_sep2018 => :environment do
    results = Hash.new do |h, k|
      h[k] = Hash.new(0)
    end

    EntityIntegrityChecker.new.check_all do |entity, issues|
      FixEntityIntegrityIssuesHelper.handle_issues(entity, issues, results)
    end

    Rails.logger.info "migrations:fix_entity_integrity_issues results = #{results.to_json}"
  end
end

module FixEntityIntegrityIssuesHelper
  def self.handle_issues(entity, issues, results)
    issues.each_key do |issue_type|
      issue_data = issues[issue_type]

      next if issue_data.nil?

      issue_type_results = results[issue_type]

      issue_type_results[:count] += 1

      success = case issue_type
      when :multiple_oc_identifiers
        issue_type_results[:entity_sources] = Hash.new(0) unless issue_type_results.key?('entity_sources')
        issue_type_results[:relationship_sources] = Hash.new(0) unless issue_type_results.key?('relationship_sources')
        handle_multiple_oc_identifiers(entity, issue_type_results)
      when :self_link_missing_company_number
        handle_self_link_missing_company_number(entity)
      end

      issue_type_results[:fixed] += 1 if success
    end
  end

  def self.handle_multiple_oc_identifiers(entity, results)
    entity_has_submission_id = entity.identifiers.any? do |i|
      i.key? 'submission_id'
    end

    results[:entities_with_submission_id] += (entity_has_submission_id ? 1 : 0)

    # Figure out the relationships associated with this entity

    relationships_as_target = entity.relationships_as_target.select do |r|
      r._id.present? # Filter out statements :(
    end
    results[:relationships_as_target] += relationships_as_target.size
    relationships_as_target_with_submission_id = relationships_as_target.select do |r|
      r._id.key? 'submission_id'
    end
    results[:relationships_as_target_with_submission_id] += relationships_as_target_with_submission_id.size

    relationships_as_source = entity.relationships_as_source
    results[:relationships_as_source] += relationships_as_source.size
    relationships_as_source_with_submission_id = relationships_as_source.select do |r|
      r._id.key? 'submission_id'
    end
    results[:relationships_as_source_with_submission_id] += relationships_as_source_with_submission_id.size

    # Log the counts of the sources of this entity + it's relationships

    entity.identifiers.each do |i|
      results[:entity_sources][i['document_id']] += 1 if i.key? 'document_id'
    end

    (relationships_as_source + relationships_as_target).each do |r|
      results[:relationship_sources][r._id['document_id']] += 1 if r._id.key? 'document_id'
    end

    if entity_has_submission_id
      Rails.logger.info "Entity '#{entity._id}' has a user submission identifier - will not delete"
      return false
    end

    if relationships_as_target_with_submission_id.size.positive?
      Rails.logger.info "Entity '#{entity._id}' has one or more relationships_as_target from a user submission - will not delete"
      return false
    end

    if relationships_as_source_with_submission_id.size.positive?
      Rails.logger.info "Entity '#{entity._id}' has one or more relationships_as_source from a user submission - will not delete"
      return false
    end

    relationships_as_target.each(&:destroy!)
    relationships_as_source.each(&:destroy!)
    IndexEntityService.new(entity).delete
    entity.destroy!

    Rails.logger.info "Entity '#{entity._id}' with multiple OC identifiers deleted along with all it's source and target relationships!"

    true
  end

  def self.handle_self_link_missing_company_number(entity)
    return false if entity.frozen? # May have been deleted by the other fix

    return false if entity.company_number.blank?

    entity.identifiers.each do |i|
      if entity.psc_self_link_identifier?(i) && !i.key?('company_number')
        i['company_number'] = entity.company_number
      end
    end

    entity.save!

    Rails.logger.info "Cleaned up self link identifier(s) that were missing company number, for Entity '#{entity._id}'"

    true
  end
end
