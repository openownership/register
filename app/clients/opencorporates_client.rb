require 'net/http/persistent'
require 'cgi'
require 'json'

class OpencorporatesClient
  class Error < StandardError
  end

  def initialize(api_token: ENV.fetch('OPENCORPORATES_API_TOKEN'))
    @api_token = api_token

    @api_url = 'https://api.opencorporates.com/'

    @http = Net::HTTP::Persistent.new(self.class.name)
  end

  def get_jurisdiction_code(name)
    response = get('/v0.4/jurisdictions/match', q: name)

    parse(response).fetch(:jurisdiction)[:code]
  end

  def get_company(jurisdiction_code, company_number)
    response = get("/v0.4/companies/#{jurisdiction_code}/#{company_number}", sparse: true)

    return if response.is_a?(Net::HTTPNotFound)

    parse(response).fetch(:company)
  end

  private

  def parse(response)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "unexpected #{response.code} response from api.opencorporates.com"
    end

    object = JSON.parse(response.body, symbolize_names: true)

    object.fetch(:results)
  end

  def get(path, params)
    params[:api_token] = @api_token

    uri = URI.join(@api_url, URI.escape(path))

    uri.query = params.map { |k, v| "#{escape(k)}=#{escape(v)}" }.join('&')

    @http.request(uri)
  end

  def escape(component)
    CGI.escape(component.to_s)
  end
end
