class EntityIntegrityChecker
  def check_all(&block)
    stats = Hash.new(0)

    total = Entity.count

    stats[:entity_count] = total

    Entity.all.each do |entity|
      stats[:processed] += 1

      Rails.logger.info "#{stats[:processed]} out of #{total} entities processed" if (stats[:processed] % 100_000).zero?

      result = check entity, &block

      result.keys.each { |k| stats[k] += 1 }
    end

    Rails.logger.info "[EntityIntegrityChecker] check_all finished with stats: #{stats.to_json}"

    stats
  end

  def check(entity)
    result = {
      no_oc_identifier: check_no_oc_identifier(entity),
      multiple_oc_identifiers: check_multiple_oc_identifiers(entity),
      self_link_missing_company_number: check_self_link_missing_company_number(entity),
    }.compact

    unless result.empty?
      Rails.logger.info "[EntityIntegrityChecker] Found issue(s) for entity '#{entity._id}': #{result.to_json}"

      yield entity, result if block_given?
    end

    result
  end

  private

  def check_no_oc_identifier(entity)
    return nil unless entity.legal_entity?

    entity.oc_identifiers.size.zero? ? {} : nil
  end

  def check_multiple_oc_identifiers(entity)
    return nil unless entity.legal_entity?

    oc_identifiers = entity.oc_identifiers

    return nil if oc_identifiers.size < 2

    {
      oc_identifiers_count: oc_identifiers.size,
      unique_oc_identifiers_count: oc_identifiers.uniq.size,
      oc_identifiers: oc_identifiers,
      company_number_set_on_record: entity.company_number,
    }
  end

  def check_self_link_missing_company_number(entity)
    return nil unless entity.legal_entity?
    return nil if entity.company_number.blank?

    self_link_identifiers_wo_company_number = entity.psc_self_link_identifiers.reject do |i|
      i.key?('company_number')
    end

    return nil if self_link_identifiers_wo_company_number.size.zero?

    {
      count: self_link_identifiers_wo_company_number.size,
    }
  end
end
