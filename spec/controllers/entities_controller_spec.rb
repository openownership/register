require 'rails_helper'

RSpec.describe EntitiesController do
  describe 'GET #opencorporates_additional_info' do
    let(:entity) { create(:legal_entity) }
    let(:oc_url) { "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/#{entity.jurisdiction_code}/#{entity.company_number}" }
    let(:oc_url_regex) { /#{Regexp.quote(oc_url)}/ }

    context 'when the OC api times out' do
      before do
        stub_request(:get, oc_url_regex).to_timeout
      end

      it 'rescues the timeout error' do
        get :opencorporates_additional_info, params: { id: entity.id }
        expect(response).to be_successful
      end

      it "doesn't set @opencorporates_company_hash" do
        get :opencorporates_additional_info, params: { id: entity.id }
        expect(assigns(:opencorporates_company_hash)).to be nil
      end

      it 'sets @oc_api_timed_out' do
        get :opencorporates_additional_info, params: { id: entity.id }
        expect(assigns(:oc_api_timed_out)).to be true
      end
    end
  end
end
