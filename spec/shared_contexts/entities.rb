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

RSpec.shared_context 'entity with intermediate ownership' do
  let!(:start_company) { create(:legal_entity, name: 'Start company') }
  let!(:intermediate_company_1) { create(:legal_entity, name: 'Intermediate company 1') }
  let!(:intermediate_company_2) { create(:legal_entity, name: 'Intermediate company 2') }
  let!(:ultimate_owner) { create(:natural_person, name: 'Ultimate owner') }

  let!(:start_to_intermediate_1_relationship) do
    FactoryGirl.create(
      :relationship,
      source: intermediate_company_1,
      target: start_company,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end
  let!(:intermediate_1_to_intermediate_2_relationship) do
    FactoryGirl.create(
      :relationship,
      source: intermediate_company_2,
      target: intermediate_company_1,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end
  let!(:intermediate_2_to_owner_relationship) do
    FactoryGirl.create(
      :relationship,
      source: ultimate_owner,
      target: intermediate_company_2,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end
  let(:start_to_owner_relationship) do
    InferredRelationship.new(
      source: ultimate_owner,
      target: start_company,
      sourced_relationships: [
        intermediate_1_to_intermediate_2_relationship,
        start_to_intermediate_1_relationship,
      ],
    )
  end
  let(:intermediate_1_to_owner_relationship) do
    InferredRelationship.new(
      source: ultimate_owner,
      target: intermediate_company_1,
      sourced_relationships: [intermediate_1_to_intermediate_2_relationship],
    )
  end

  before do
    Entity.import(force: true, refresh: true)
    stub_oc_company_api_for(start_company)
    stub_oc_company_api_for(intermediate_company_1)
    stub_oc_company_api_for(intermediate_company_2)
  end
end

RSpec.shared_context 'entity with ownership at different levels' do
  let!(:start_company) { create(:legal_entity, name: 'Start company') }
  let!(:direct_owner) { create(:natural_person, name: 'Direct owner') }
  let!(:intermediate_company) { create(:legal_entity, name: 'Intermediate company') }
  let!(:ultimate_owner) { create(:natural_person, name: 'Ultimate owner') }

  let!(:start_to_direct_owner_relationship) do
    FactoryGirl.create(
      :relationship,
      source: direct_owner,
      target: start_company,
      interests: ['ownership-of-shares-25-to-50-percent'],
    )
  end
  let!(:start_to_intermediate_relationship) do
    FactoryGirl.create(
      :relationship,
      source: intermediate_company,
      target: start_company,
      interests: ['ownership-of-shares-25-to-50-percent'],
    )
  end
  let!(:intermediate_to_ultimate_owner_relationship) do
    FactoryGirl.create(
      :relationship,
      source: ultimate_owner,
      target: intermediate_company,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end
  let!(:start_to_ultimate_owner_relationship) do
    InferredRelationship.new(
      source: ultimate_owner,
      target: start_company,
      sourced_relationships: [start_to_intermediate_relationship],
    )
  end

  before do
    Entity.import(force: true, refresh: true)
    stub_oc_company_api_for(start_company)
    stub_oc_company_api_for(intermediate_company)
  end
end

RSpec.shared_context 'entity with no ultimate ownership' do
  let!(:start_company) { create(:legal_entity, name: 'Start company') }
  let!(:intermediate_company) { create(:legal_entity, name: 'Intermediate company') }
  let!(:start_to_intermediate_relationship) do
    FactoryGirl.create(
      :relationship,
      source: intermediate_company,
      target: start_company,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end
  let!(:intermediate_owner_statement) do
    FactoryGirl.create(:statement, entity: intermediate_company)
  end
  let!(:no_owner) do
    UnknownPersonsEntity.new(
      id: "statement-descriptions-no-individual-or-entity-with-signficant-control",
      name: I18n.t("statement-descriptions.no-individual-or-entity-with-signficant-control"),
    )
  end
  let!(:intermediate_to_no_owner_relationship) do
    Relationship.new(source: no_owner, target: intermediate_company)
  end
  let!(:start_to_no_owner_relationship) do
    InferredRelationship.new(
      source: no_owner,
      target: start_company,
      sourced_relationships: [start_to_intermediate_relationship],
    )
  end

  before do
    Entity.import(force: true, refresh: true)
    stub_oc_company_api_for(start_company)
    stub_oc_company_api_for(intermediate_company)
  end
end

RSpec.shared_context 'entity with unknown ultimate ownership' do
  let!(:start_company) { create(:legal_entity, name: 'Start company') }
  let!(:intermediate_company) { create(:legal_entity, name: 'Intermediate company') }
  let!(:start_to_intermediate_relationship) do
    FactoryGirl.create(
      :relationship,
      source: intermediate_company,
      target: start_company,
      interests: ['ownership-of-shares-75-to-100-percent'],
    )
  end
  let!(:unknown_owner) do
    UnknownPersonsEntity.new(
      id: "#{intermediate_company.id}-unknown",
      name: "unknown",
    )
  end
  let!(:intermediate_to_unknown_owner_relationship) do
    Relationship.new(source: unknown_owner, target: intermediate_company)
  end
  let!(:start_to_unknown_owner_relationship) do
    InferredRelationship.new(
      source: unknown_owner,
      target: start_company,
      sourced_relationships: [start_to_intermediate_relationship],
    )
  end

  before do
    Entity.import(force: true, refresh: true)
    stub_oc_company_api_for(start_company)
    stub_oc_company_api_for(intermediate_company)
  end
end
