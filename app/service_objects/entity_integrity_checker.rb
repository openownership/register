class EntityIntegrityChecker
  def check_all(&block)
    stats = Hash.new(0)

    total = Entity.count

    stats[:entity_count] = total

    Entity.all.each do |entity|
      stats[:processed] += 1

      Rails.logger.info "[#{self.class.name}] #{stats[:processed]} out of #{total} entities processed" if (stats[:processed] % 100_000).zero?

      result = check entity, &block

      result.keys.each { |k| stats[k] += 1 }
    end

    Rails.logger.info "[#{self.class.name}] check_all finished with stats: #{stats.to_json}"

    stats
  end

  def check(entity)
    result = %i[
      no_oc_identifier
      multiple_oc_identifiers
      self_link_missing_company_number
      missing_company_number_field
      no_company_number_at_all
      multiple_company_numbers
      no_relationships
    ].each_with_object({}) do |c, acc|
      acc[c] = send("check_#{c}", entity)
    end.compact

    unless result.empty?
      Rails.logger.info "[#{self.class.name}] Found issue(s) for entity '#{entity._id}': #{result.to_json}"

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

  def check_missing_company_number_field(entity)
    return nil unless entity.legal_entity?

    entity.company_number.blank? ? {} : nil
  end

  def check_no_company_number_at_all(entity)
    return nil unless entity.legal_entity?
    return nil if entity.company_number.present?

    company_numbers = unique_company_numbers_for entity

    company_numbers.size.zero? ? {} : nil
  end

  def check_multiple_company_numbers(entity)
    return nil unless entity.legal_entity?

    company_numbers = unique_company_numbers_for entity

    return nil if company_numbers.size < 2

    {
      company_numbers: company_numbers,
    }
  end

  def check_no_relationships(entity)
    as_source_count = Relationship.where(source_id: entity.id).count
    as_target_count = Relationship.where(target_id: entity.id).count

    return nil if as_source_count.positive? || as_target_count.positive?

    {
      type: entity.type,
    }
  end

  def unique_company_numbers_for(entity)
    (
      [entity.company_number] +
      entity.identifiers.map do |i|
        i['company_number']
      end
    ).compact.uniq.sort
  end
end
