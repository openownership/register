module AdminHelpers
  def stub_elasticsearch
    stub_request(:any, /#{ENV['SEARCHBOX_SSL_URL']}.*/)
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
