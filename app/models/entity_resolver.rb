class EntityResolver
  def initialize(opencorporates_client: OpencorporatesClient.new, reconciliation_client: ReconciliationClient.new)
    @opencorporates_client = opencorporates_client

    @reconciliation_client = reconciliation_client
  end

  def resolve!(jurisdiction_code:, identifier:, name:)
    if identifier
      response = @opencorporates_client.get_company(jurisdiction_code, identifier)

      return entity!(response) unless response.nil?

      response = @opencorporates_client.search_companies(jurisdiction_code, identifier)

      return entity!(response.first.fetch(:company)) unless response.empty?
    else
      response = @reconciliation_client.reconcile(jurisdiction_code, name)

      return if response.nil?

      resolve!(
        jurisdiction_code: response.fetch(:jurisdiction_code),
        identifier: response.fetch(:company_number),
        name: response.fetch(:name),
      )
    end
  end

  private

  def entity!(response)
    attributes = {
      identifiers: [
        {
          _id: {
            jurisdiction_code: response.fetch(:jurisdiction_code),
            company_number: response.fetch(:company_number),
          },
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

    Entity.new(attributes).tap(&:upsert)
  end
end
