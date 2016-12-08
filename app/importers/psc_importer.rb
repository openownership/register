require 'net/http/persistent'
require 'json'

class PscImporter
  def initialize(api_token: ENV.fetch('OPENCORPORATES_API_TOKEN'))
    @api_token = api_token

    @api_url = 'https://api.opencorporates.com/v0.4'

    @http = Net::HTTP::Persistent.new(self.class.name)
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
          name: get_company_name(record.fetch(:company_number)),
          company_number: record.fetch(:company_number)
        }

        entities << {
          _id: controlling_entity_id,
          name: data.fetch(:name)
        }

        relationships << relationship(controlling_entity_id, controlled_company_id)
      else
        raise "unexpected kind: #{data.fetch(:kind)}"
      end
    end
  end

  private

  def relationship(source_id, target_id)
    {
      _id: BSON::ObjectId.new,
      source_id: source_id,
      target_id: target_id
    }
  end

  def get_company_name(company_number)
    uri = URI("#{@api_url}/companies/gb/#{company_number}?sparse=true&api_token=#{@api_token}")

    response = @http.request(uri)

    return unless response.is_a?(Net::HTTPSuccess)

    object = JSON.parse(response.body, symbolize_names: true)

    object.fetch(:results).fetch(:company).fetch(:name)
  end
end
