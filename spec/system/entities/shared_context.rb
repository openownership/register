require 'rails_helper'

RSpec.shared_context 'basic entity with stubbed OC api' do
  let!(:company) { create(:legal_entity) }
  let!(:person) { create(:natural_person) }
  let!(:relationship) do
    FactoryGirl.create(
      :relationship,
      source: person,
      target: company,
      interests: ['ownership-of-shares-25-to-50-percent'],
    )
  end
  let(:oc_url) { "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/#{company.jurisdiction_code}/#{company.company_number}" }
  let(:oc_url_regex) { /#{Regexp.quote(oc_url)}/ }

  before do
    stub_request(:get, oc_url_regex).to_return(
      body: '{"results":{"company":{"name":"EXAMPLE LIMITED","previous_names":[{"company_name":"FOO LIMITED"}],"industry_codes":[],"officers":[]}}}',
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  def ownership_summary
    I18n.t("relationship_interests.#{relationship.interests.first}")
  end
end
