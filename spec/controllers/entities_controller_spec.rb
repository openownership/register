require 'rails_helper'

RSpec.describe EntitiesController do
  describe 'GET #show' do
    let(:entity) { create(:legal_entity) }

    it 'sorts owned companies by ended_date and name' do
      first_company = create(:legal_entity, name: 'ABC')
      second_company = create(:legal_entity, name: 'ABC')
      third_company = create(:legal_entity, name: 'DEF')
      fourth_company = create(:legal_entity, name: 'DEF')

      first_relationship = create(:relationship, source: entity, target: first_company, ended_date: nil)
      second_relationship = create(:relationship, source: entity, target: second_company, ended_date: Time.zone.today.iso8601)
      third_relationship = create(:relationship, source: entity, target: third_company, ended_date: nil)
      fourth_relationship = create(:relationship, source: entity, target: fourth_company, ended_date: Time.zone.today.iso8601)

      expected_order = [
        first_relationship.id,
        third_relationship.id,
        second_relationship.id,
        fourth_relationship.id,
      ]

      get :show, params: { id: entity.id }

      # The actual results get paginated and decorated so aren't Relationships
      # instances, hence just matching ids
      actual_order = assigns('source_relationships').map(&:id)
      expect(actual_order).to eq(expected_order)
    end
  end

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
