require 'rails_helper'

RSpec.describe 'Viewing a relationship' do
  include EntityHelpers

  def expect_person_details_for(person)
    expect(page).to have_text person.name
    expect(page).to have_text 'British'
    expect(page).to have_text "Born #{birth_month_year(person)}"
  end

  def expect_company_details_for(company)
    expect(page).to have_text company.name
    expect(page).to have_text company.incorporation_date.iso8601
    expect(page).to have_text 'United Kingdom'
  end

  def expect_relationship_details_for(relationship)
    expect(page).to have_text interests_summary(relationship)
    expect(page).to have_link(
      relationship.provenance.source_name,
      href: relationship.provenance.source_url,
    )
    expect(page).to have_text "Retrieved: #{retrieved_date(relationship)}"
  end

  def retrieved_date(relationship)
    relationship.provenance.retrieved_at.to_date.iso8601
  end

  context 'basic entity with one owner' do
    include_context 'basic entity with one owner'

    it 'shows useful info for the relationship' do
      visit entity_relationship_path(company, person)

      expect(page).to have_text "Beneficial ownership chain: #{person.name} to #{company.name}"
      expect_company_details_for(company)
      expect_person_details_for(person)
      expect_relationship_details_for(relationship)

      expect(page).to have_link 'Report incorrect data'
    end
  end

  context 'entity with intermediate ownership' do
    include_context 'entity with intermediate ownership'

    it 'shows the full chain of relationships' do
      visit entity_relationship_path(start_company, ultimate_owner)

      expect_company_details_for(start_company)
      expect_company_details_for(intermediate_company1)
      expect_company_details_for(intermediate_company2)
      expect_person_details_for(ultimate_owner)
      expect_relationship_details_for(start_to_intermediate_1_relationship)
      expect_relationship_details_for(intermediate_1_to_intermediate_2_relationship)
      expect_relationship_details_for(intermediate_2_to_owner_relationship)
    end
  end

  context 'entity with no ultimate ownership' do
    include_context 'entity with no ultimate ownership'

    it 'shows the ownership chain with no-one at the top' do
      visit entity_relationship_path(start_company, no_owner)

      expect_company_details_for(start_company)
      expect_company_details_for(intermediate_company)
      expect(page).to have_css('.entity-link', text: 'No person')

      expect_relationship_details_for(start_to_intermediate_relationship)
      expect(page).to have_css('.relationship-interests', text: 'Interests unknown')
    end
  end

  context 'entity with unknown ultimate ownership' do
    include_context 'entity with unknown ultimate ownership'

    it 'shows the ownership chain with an unknown owner at the top' do
      visit entity_relationship_path(start_company, unknown_owner)

      expect_company_details_for(start_company)
      expect_company_details_for(intermediate_company)
      expect(page).to have_css('.entity-link', text: 'Unknown')

      expect_relationship_details_for(start_to_intermediate_relationship)
      expect(page).to have_css('.relationship-interests', text: 'Interests unknown')
    end
  end

  context 'entity with circular ownership and an ultimate owner' do
    include_context 'entity with circular ownership and an ultimate owner'

    it 'ignores the circular ownership and shows the ownership chain' do
      visit entity_relationship_path(start_company, ultimate_owner)

      expect_company_details_for(start_company)
      expect_company_details_for(intermediate_company)
      expect_person_details_for(ultimate_owner)
      expect_relationship_details_for(start_to_intermediate_relationship)
      expect_relationship_details_for(intermediate_to_ultimate_owner_relationship)
    end
  end

  context 'entity with diamond ownership' do
    include_context 'entity with diamond ownership'

    it 'shows both sides of the diamond' do
      visit entity_relationship_path(start_company, ultimate_owner)

      expect_company_details_for(start_company)
      expect_company_details_for(intermediate_company1)
      expect_company_details_for(intermediate_company2)
      expect_person_details_for(ultimate_owner)
      expect_relationship_details_for(start_to_intermediate_1_relationship)
      expect_relationship_details_for(start_to_intermediate_2_relationship)
      expect_relationship_details_for(intermediate_1_to_owner_relationship)
      expect_relationship_details_for(intermediate_2_to_owner_relationship)
    end
  end
end
