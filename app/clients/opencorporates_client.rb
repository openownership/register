require 'net/http/persistent'
require 'json'

class OpencorporatesClient
  API_VERSION = 'v0.4.6'.freeze

  def self.new_for_imports
    new(
      api_token: Rails.application.config.oc_api.token_protected,
      open_timeout: 30.0,
      read_timeout: 60.0,
    )
  end

  def self.new_for_app(timeout:)
    new(
      api_token: Rails.application.config.oc_api.token,
      open_timeout: timeout,
      read_timeout: timeout,
    )
  end

  def initialize(api_token:, open_timeout:, read_timeout:)
    @api_token = api_token

    @connection = Faraday.new(url: "https://api.opencorporates.com") do |c|
      c.request :json

      c.response :follow_redirects

      c.response :json,
                 content_type: /\bjson$/,
                 parser_options: { symbolize_names: true }

      c.adapter :net_http_persistent do |http|
        http.open_timeout = open_timeout
        http.read_timeout = read_timeout
      end
    end
  end

  def get_jurisdiction_code(name)
    response = get('/jurisdictions/match', q: name)

    return unless response

    response.fetch(:jurisdiction)[:code]
  end

  def get_company(jurisdiction_code, company_number, sparse: true)
    params = {}
    params[:sparse] = true if sparse

    response = get("/companies/#{jurisdiction_code}/#{company_number}", params)

    return unless response

    response.fetch(:company)
  end

  def search_companies(jurisdiction_code, company_number)
    params = {
      q: company_number,
      jurisdiction_code: jurisdiction_code,
      fields: 'company_number',
      order: 'score',
    }

    response = get('/companies/search', params)

    return [] unless response

    response.fetch(:companies)
  end

  def search_companies_by_name(name)
    params = {
      q: name,
      fields: 'company_name',
      order: 'score',
    }

    response = get('/companies/search', params)

    return [] unless response

    response.fetch(:companies)
  end

  private

  def get(path, params)
    normalised_path = Addressable::URI.parse("/#{API_VERSION}#{path}").normalize.to_s

    response = @connection.get do |req|
      req.url normalised_path, params
      req.params['api_token'] = @api_token
      req.headers['Accept'] = 'application/json'
    end

    if response.success?
      response.body.fetch(:results)
    else
      Rails.logger.info("Received #{response.status} from api.opencorporates.com when calling #{path} (#{params})")
      nil
    end
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    Rails.logger.info("Received #{e.inspect} when calling #{path} (#{params})")
    nil
  end
end
