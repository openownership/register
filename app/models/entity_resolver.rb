class EntityResolver
  def initialize(opencorporates_client: OpencorporatesClient.new, reconciliation_client: ReconciliationClient.new)
    @opencorporates_client = opencorporates_client

    @reconciliation_client = reconciliation_client
  end

  def resolve!(jurisdiction_code:, identifier:, name:)
    if identifier
      response = @opencorporates_client.get_company(jurisdiction_code, identifier)

      return find_or_create_entity!(response) unless response.nil?

      response = @opencorporates_client.search_companies(jurisdiction_code, identifier)

      return find_or_create_entity!(response.first.fetch(:company)) unless response.empty?
    else
      response = @reconciliation_client.reconcile(jurisdiction_code, name)

      return find_or_create_entity!(response) unless response.nil?
    end
  end

  private

  def find_or_create_entity!(response)
    id = {
      _id: {
        jurisdiction_code: response.fetch(:jurisdiction_code),
        company_number: response.fetch(:company_number)
      }
    }

    Entity.where(identifiers: id).first_or_create!(identifiers: [id], name: response.fetch(:name))
  end
end
