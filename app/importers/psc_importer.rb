require 'json'

class PscImporter
  def initialize(client: OpencorporatesClient.new)
    @client = client
  end

  def entities
    @entities ||= []
  end

  def relationships
    @relationships ||= []
  end

  def parse(file)
    file.each_line do |line|
      record = JSON.parse(line, symbolize_names: true)

      data = record.fetch(:data)

      case data.fetch(:kind)
      when 'totals#persons-of-significant-control-snapshot'
        :ignore
      when 'persons-with-significant-control-statement'
        :ignore
      when /(individual|corporate-entity|legal-person)-person-with-significant-control/
        controlled_company_id = BSON::ObjectId.new

        controlling_entity_id = BSON::ObjectId.new

        entities << {
          _id: controlled_company_id,
          name: @client.get_company('gb', record.fetch(:company_number)).fetch(:name),
          identifiers: [identifier('gb', record.fetch(:company_number))]
        }

        entities << {
          _id: controlling_entity_id,
          name: data.fetch(:name),
          identifiers: corporate_entity_identifiers(data)
        }

        relationships << relationship(controlling_entity_id, controlled_company_id)
      else
        raise "unexpected kind: #{data.fetch(:kind)}"
      end
    end
  end

  private

  def corporate_entity_identifiers(data)
    return unless data.fetch(:kind).start_with?('corporate-entity-person')

    identification = data.fetch(:identification)

    return if identification[:country_registered].nil?

    jurisdiction_code = @client.get_jurisdiction_code(identification[:country_registered])

    return if jurisdiction_code.nil?

    company = @client.get_company(jurisdiction_code, identification.fetch(:registration_number))

    return if company.nil?

    [identifier(jurisdiction_code, company.fetch(:company_number))]
  end

  def identifier(jurisdiction_code, company_number)
    {
      _id: {
        jurisdiction_code: jurisdiction_code,
        company_number: company_number
      }
    }
  end

  def relationship(source_id, target_id)
    {
      _id: BSON::ObjectId.new,
      source_id: source_id,
      target_id: target_id
    }
  end
end
