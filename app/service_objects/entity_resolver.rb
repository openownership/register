class EntityResolver
  def initialize(opencorporates_client: OpencorporatesClient.new, reconciliation_client: ReconciliationClient.new)
    @opencorporates_client = opencorporates_client

    @reconciliation_client = reconciliation_client
  end

  def resolve!(entity)
    if entity.company_number
      response = @opencorporates_client.get_company(entity.jurisdiction_code, entity.company_number)

      return entity!(response) unless response.nil?

      response = @opencorporates_client.search_companies(entity.jurisdiction_code, entity.company_number)

      return entity!(response.first.fetch(:company)) unless response.empty?
    else
      response = @reconciliation_client.reconcile(entity.jurisdiction_code, entity.name)

      return if response.nil?

      entity = Entity.new(
        jurisdiction_code: response.fetch(:jurisdiction_code),
        company_number: response.fetch(:company_number),
        name: response.fetch(:name),
      )

      resolve!(entity)
    end
  end

  private

  def entity!(response)
    attributes = {
      identifiers: [
        {
          'jurisdiction_code' => response.fetch(:jurisdiction_code),
          'company_number' => response.fetch(:company_number),
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      name: response.fetch(:name),
      address: response[:registered_address_in_full].presence.try(:gsub, "\n", ", "),
      jurisdiction_code: response[:jurisdiction_code].presence,
      company_number: response[:company_number].presence,
      incorporation_date: response[:incorporation_date].presence,
      dissolution_date: response[:dissolution_date].presence,
      company_type: response[:company_type].presence,
    }

    Entity.new(attributes)
  end
end
