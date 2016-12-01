require 'net/http/persistent'
require 'json'

class PscImporter
  def initialize(api_token: ENV.fetch('OPENCORPORATES_API_TOKEN'))
    @api_token = api_token

    @api_url = 'https://api.opencorporates.com/v0.4'

    @http = Net::HTTP::Persistent.new(self.class.name)
  end

  def parse(file)
    entities = []

    file.each_line do |line|
      record = JSON.parse(line, symbolize_names: true)

      data = record.fetch(:data)

      case data.fetch(:kind)
      when 'totals#persons-of-significant-control-snapshot'
        :ignore
      when 'persons-with-significant-control-statement'
        :ignore
      when /(individual|corporate-entity|legal-person)-person-with-significant-control/
        company_number = record.fetch(:company_number)

        entities << {
          _id: BSON::ObjectId.new,
          name: get_company_name(company_number),
          company_number: company_number
        }

        entities << {
          _id: BSON::ObjectId.new,
          name: data.fetch(:name)
        }
      else
        raise "unexpected kind: #{data.fetch(:kind)}"
      end
    end

    entities
  end

  private

  def get_company_name(company_number)
    uri = URI("#{@api_url}/companies/gb/#{company_number}?sparse=true&api_token=#{@api_token}")

    response = @http.request(uri)

    return unless response.is_a?(Net::HTTPSuccess)

    object = JSON.parse(response.body, symbolize_names: true)

    object.fetch(:results).fetch(:company).fetch(:name)
  end
end
