module AdminHelpers
  def admin_basic_auth
    ActionController::HttpAuthentication::Basic.encode_credentials(*ENV.fetch('ADMIN_BASIC_AUTH').split(':'))
  end

  def stub_elasticsearch
    uri = URI.parse ENV[ENV['ELASTICSEARCH_URL_ENV_NAME']]
    stub_request(:any, /#{uri.host}:#{uri.port}/)
  end

  def stub_opencorporates_client_get_company
    allow(opencorporates_client).to receive(:get_company).and_return(nil)
  end

  def stub_opencorporates_client_search_companies
    allow(opencorporates_client).to receive(:search_companies).and_return([])
  end

  private

  def opencorporates_client
    @opencorporates_client ||= instance_double("OpencorporatesClient").tap do |instance|
      allow(OpencorporatesClient).to receive(:new).and_return(instance)
      allow(instance).to receive(:http).and_return(double.as_null_object)
    end
  end
end
