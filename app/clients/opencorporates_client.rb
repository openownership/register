require 'net/http/persistent'
require 'json'

class OpencorporatesClient
  extend Memoist

  API_VERSION = 'v0.4.6'.freeze

  def self.new_for_imports
    new(api_token: Rails.application.config.oc_api.token_protected)
  end

  attr_reader :http

  def initialize(api_token: Rails.application.config.oc_api.token)
    @api_token = api_token

    @api_url = 'https://api.opencorporates.com/'

    @http = Net::HTTP::Persistent.new(self.class.name)
  end

  def get_jurisdiction_code(name)
    response = get("/#{API_VERSION}/jurisdictions/match", q: name)
    return unless response

    parse(response).fetch(:jurisdiction)[:code]
  end
  memoize :get_jurisdiction_code

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
  rescue Net::HTTP::Persistent::Error, Net::OpenTimeout => e
    Rails.logger.info("Received #{e.inspect} when calling #{path} (#{params})")
    nil
  end
end
