require 'net/http/persistent'
require 'json'

class SkClient
  def initialize
    @api_url = 'https://rpvs.gov.sk/OpenData/Partneri'

    @http = Net::HTTP::Persistent.new(self.class.name)
  end

  def all_records
    uri = URI("#{@api_url}?$expand=PartneriVerejnehoSektora($expand=*),KonecniUzivateliaVyhod($expand=*)")

    Enumerator.new do |yielder|
      response = fetch(uri, yielder)

      while response && response['@odata.nextLink']
        response = fetch(response['@odata.nextLink'], yielder)
      end
    end
  end

  private

  def fetch(uri, yielder)
    response = @http.request(URI(uri))

    unless response.is_a?(Net::HTTPSuccess)
      Rollbar.error("#{response.code} received when importing sk data")
      return nil
    end

    JSON.parse(response.body, object_class: OpenStruct).tap do |object|
      object.value.each { |record| yielder << record }
    end
  end
end
