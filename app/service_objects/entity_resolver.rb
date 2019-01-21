class EntityResolver
  def initialize(opencorporates_client: OpencorporatesClient.new_for_imports, reconciliation_client: ReconciliationClient.new)
    @opencorporates_client = opencorporates_client

    @reconciliation_client = reconciliation_client
  end

  def resolve!(entity)
    if entity.company_number
      response = @opencorporates_client.get_company(entity.jurisdiction_code, entity.company_number)

      unless response.nil?
        merge(entity, response)
        return
      end

      response = @opencorporates_client.search_companies(entity.jurisdiction_code, entity.company_number)

      unless response.empty?
        log_reconciliation_changes(entity, response.first.fetch(:company))
        merge(entity, response.first.fetch(:company))
        return
      end
    else
      response = @reconciliation_client.reconcile(entity.jurisdiction_code, entity.name)

      return if response.nil?

      log_reconciliation_changes(entity, response)

      entity.assign_attributes(
        jurisdiction_code: response.fetch(:jurisdiction_code),
        company_number: response.fetch(:company_number),
        name: response.fetch(:name),
      )

      resolve!(entity)
    end
  end

  private

  def merge(entity, response)
    attributes = {
      name: response.fetch(:name),
      address: response[:registered_address_in_full].presence.try(:gsub, "\n", ", "),
      jurisdiction_code: response[:jurisdiction_code].presence,
      company_number: response[:company_number].presence,
      incorporation_date: response[:incorporation_date].presence,
      dissolution_date: response[:dissolution_date].presence,
      company_type: response[:company_type].presence,
      restricted_for_marketing: response[:restricted_for_marketing],
    }

    entity.assign_attributes(attributes)
    entity.add_oc_identifier(response)
  end

  def log_reconciliation_changes(entity, oc_data)
    original_number = normalise_company_number(entity.company_number)
    new_number = normalise_company_number(oc_data.fetch(:company_number))
    return if original_number == new_number
    msg = "[#{self.class.name}] Resolution with OpenCorporates changed the " \
          "company number of Entity with identifiers: #{entity.identifiers}. " \
          "Old number: #{entity.company_number}. " \
          "New number: #{oc_data.fetch(:company_number)}. " \
          "Old name: #{entity.name}. New name: #{oc_data.fetch(:name)}."
    Rails.logger.info msg
  end

  # Slightly reverse-engineered version of the normalisation that OpenCorporates
  # does to company numbers, to help make meaningful changes more obvious
  def normalise_company_number(original_number)
    number = original_number.nil? ? "" : original_number.dup
    # Strip leading zeroes
    number.sub!(/^[0]+/, '')
    # Remove spaces
    number.gsub!(/\s/, '')
    # Turn various separators into dashes
    number.gsub!(%r{[/\.]}, '-')
    # Uppercase everything
    number.upcase!
    number
  end
end
