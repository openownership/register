require 'net/http/persistent'
require 'oj'

class SkClient
  def initialize
    @api_url = 'https://rpvs.gov.sk/OpenData/Partneri'
    # The api uses OData, which defines it's own system of url params that allow
    # you to (amongst other things) request that records are 'expanded', i.e.
    # eagerly fetched and nested in the results.
    # This parameter 'expands' Partneri and Konecni, the company and people
    # records for each result, expanding all their sub-properties in turn.
    @record_expansion_param = '$expand=PartneriVerejnehoSektora($expand=*),KonecniUzivateliaVyhod($expand=*)'

    @http = Net::HTTP::Persistent.new(self.class.name)
  end

  def all_records
    uri = "#{@api_url}?#{@record_expansion_param}"

    Enumerator.new do |yielder|
      response = yield_response(fetch(uri), yielder)

      while response && response['@odata.nextLink']
        response = yield_response(fetch(response['@odata.nextLink']), yielder)
      end
    end
  end

  def company_record(company_id)
    uri = "#{@api_url}(#{company_id})?#{@record_expansion_param}"
    response = fetch(uri)
    return if response.nil?
    Oj.load(response.body, mode: :rails)
  end

  private

  def fetch(uri)
    response = @http.request(URI(uri))

    unless response.is_a?(Net::HTTPSuccess)
      Rollbar.error("#{response.code} received when importing sk data")
      return nil
    end

    response
  end

  def yield_response(response, yielder)
    return if response.nil?
    Oj.load(response.body, mode: :rails).tap do |object|
      object['value'].each { |record| yielder << record }
    end
  end
end
