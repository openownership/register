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
