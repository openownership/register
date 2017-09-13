require 'net/http/persistent'
require 'json'

class OpencorporatesClient
  API_VERSION = 'v0.4.6'.freeze

  attr_reader :http

  def initialize(api_token: ENV.fetch('OPENCORPORATES_API_TOKEN'))
    @api_token = api_token

    @api_url = 'https://api.opencorporates.com/'

    @http = Net::HTTP::Persistent.new(self.class.name)
  end

  def get_jurisdiction_code(name)
    response = get("/#{API_VERSION}/jurisdictions/match", q: name)
    return unless response

    parse(response).fetch(:jurisdiction)[:code]
  end

  def get_company(jurisdiction_code, company_number, sparse: true)
    params = {}
    params[:sparse] = true if sparse

    response = get("/#{API_VERSION}/companies/#{jurisdiction_code}/#{company_number}", params)
    return unless response

    parse(response).fetch(:company)
  end

  def search_companies(jurisdiction_code, company_number)
    params = {
      q: company_number,
      jurisdiction_code: jurisdiction_code,
      fields: 'company_number',
      order: 'score',
    }

    response = get("/#{API_VERSION}/companies/search", params)
    return [] unless response

    parse(response).fetch(:companies)
  end

  def search_companies_by_name(name)
    params = {
      q: name,
      fields: 'company_name',
      order: 'score',
    }

    response = get("/#{API_VERSION}/companies/search", params)
    return [] unless response

    parse(response).fetch(:companies)
  end

  private

  def parse(response)
    object = JSON.parse(response.body, symbolize_names: true)

    object.fetch(:results)
  end

  def get(path, params)
    params[:api_token] = @api_token

    uri = URI(Addressable::URI.parse(Addressable::URI.join(@api_url, path)).normalize.to_s)
    uri.query = params.to_query

    response = @http.request(uri)

    if response.is_a?(Net::HTTPSuccess)
      response
    else
      Rails.logger.info("Received #{response.code} from api.opencorporates.com when calling #{path} (#{params})")
      nil
    end
  rescue Net::HTTP::Persistent::Error => e
    Rails.logger.info("Received #{e.inspect} when calling #{path} (#{params})")
    nil
  end
end
