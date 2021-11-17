require 'net/http/persistent'
require 'cgi'
require 'json'

class ReconciliationClient
  class Error < StandardError
  end

  def initialize
    @http = Net::HTTP::Persistent.new(name: self.class.name)
  end

  def reconcile(jurisdiction_code, search_query)
    uri = URI("https://opencorporates.com/reconcile/#{jurisdiction_code}?query=" + escape(search_query))

    response = @http.request(uri)

    results = parse(response).fetch(:result)

    return if results.empty?

    result = results.first

    %r{^/companies/(?<jurisdiction_code>[^/]+)/(?<company_number>[^/]+)$} =~ result.fetch(:id)

    {
      name: result.fetch(:name),
      jurisdiction_code: jurisdiction_code,
      company_number: company_number,
    }
  rescue Net::HTTP::Persistent::Error => e
    Rails.logger.info("Received #{e.inspect} when reconciling \"#{search_query}\" (#{jurisdiction_code})")
    nil
  end

  private

  def parse(response)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "unexpected #{response.code} response from opencorporates.com/reconcile"
    end

    JSON.parse(response.body, symbolize_names: true)
  end

  def escape(component)
    CGI.escape(component.to_s)
  end
end
