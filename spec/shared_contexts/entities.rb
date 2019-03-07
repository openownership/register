require 'rails_helper'

RSpec.shared_context 'basic entity with one owner' do
  let!(:company) { create(:legal_entity) }
  let!(:person) { create(:natural_person) }
  let!(:relationship) do
    FactoryGirl.create(
      :relationship,
      source: person,
      target: company,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end

  before do
    Entity.import(force: true, refresh: true)
    stub_oc_company_api_for(company)
  end
end

RSpec.shared_context 'entity with two owners' do
  let!(:company) { create(:legal_entity) }
  let!(:person_1) { create(:natural_person) }
  let!(:person_2) { create(:natural_person) }
  let!(:relationship_1) do
    FactoryGirl.create(
      :relationship,
      source: person_1,
      target: company,
      interests: ['ownership-of-shares-25-to-50-percent'],
    )
  end
  let!(:relationship_2) do
    FactoryGirl.create(
      :relationship,
      source: person_2,
      target: company,
      interests: ['ownership-of-shares-25-to-50-percent'],
    )
  end
  let(:oc_url) { "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/#{company.jurisdiction_code}/#{company.company_number}" }
  let(:oc_url_regex) { /#{Regexp.quote(oc_url)}/ }

  before do
    Entity.import(force: true, refresh: true)
    stub_request(:get, oc_url_regex).to_return(
      body: '{"results":{"company":{"name":"EXAMPLE LIMITED","previous_names":[{"company_name":"FOO LIMITED"}],"industry_codes":[],"officers":[]}}}',
      headers: { 'Content-Type' => 'application/json' },
    )
  end
end
