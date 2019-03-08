require 'rails_helper'

RSpec.describe 'Entity pages' do
  include EntityHelpers

  def expect_beneficial_owner_section_for(relationship)
    owner = relationship.source
    within '.ultimate-source-relationships' do
      expect(page).to have_selector '.entity-link', text: owner.name
      expect(page).to have_link owner.name
      expect(page).to have_selector '.entity-link', text: "Born #{birth_month_year(owner)}"
      expect(page).to have_link "", href: relationship_href(relationship)
    end
  end

  def expect_controlled_company_section_for(relationship)
    company = relationship.target
    within '.source-relationships' do
      expect(page).to have_selector '.entity-link', text: company.name
      expect(page).to have_link company.name
      expect(page).to have_selector '.entity-link', text: company.incorporation_date.iso8601
      expect(page).to have_link "", href: relationship_href(relationship)
    end
  end

  context 'for a simple one person, one company ownership' do
    include_context 'basic entity with one owner'

    it 'shows useful info for the company' do
      visit entity_path(company)

      expect(page).to have_text company.incorporation_date.iso8601
      expect(page).to have_text company.company_number

      expect(page).to have_link 'Google'
      expect(page).to have_link 'Report incorrect data'
      expect(page).to have_link 'View as tree'

      expect(page).to have_text "Beneficial owners of #{company.name}"
      expect(page).to have_text interests_summary(relationship)
      expect_beneficial_owner_section_for relationship

      expect(page).to have_text "No companies are known to be controlled by #{company.name}"
    end

    it 'shows useful info for the person' do
      visit entity_path(person)

      expect(page).to have_text person.address
      expect(page).to have_text 'British'
      expect(page).to have_text person.nationality
      expect(page).to have_text birth_month_year(person)

      expect(page).to have_link 'Google'
      expect(page).to have_link 'Report incorrect data'
      expect(page).not_to have_link 'View as tree'

      expect(page).not_to have_text "Beneficial owners of #{person.name}"

      expect(page).to have_text "Companies controlled by #{person.name}"
      expect_controlled_company_section_for relationship
    end
  end

  context 'for a company that owns lots of others' do
    include_context 'basic entity with one owner'

    let!(:relationships) do
      FactoryGirl.create_list(
        :relationship,
        10,
        source: company,
        interests: ['ownership-of-shares-75-to-100-percent'],
      )
    end

    let!(:ended_relationship_1) do
      FactoryGirl.create(
        :relationship,
        source: company,
        interests: ['ownership-of-shares-75-to-100-percent'],
        ended_date: Time.zone.yesterday.iso8601,
      )
    end

    let!(:ended_relationship_2) do
      FactoryGirl.create(
        :relationship,
        source: company,
        interests: ['ownership-of-shares-75-to-100-percent'],
        ended_date: Time.zone.today.iso8601,
      )
    end

    let(:ended_company_1) { ended_relationship_1.target }
    let(:ended_company_2) { ended_relationship_2.target }

    it 'paginates the list of owned companies' do
      visit entity_path(company)
      expect(page).to have_text 'Displaying companies 1 - 10 of 12 in total'

      within '.pagination' do
        within '.current' do
          expect(page).to have_text('1')
        end
        expect(page).to have_link '2'
        expect(page).to have_link 'Next ›'
        expect(page).to have_link 'Last »'
        click_link '2'
      end

      within '.pagination' do
        expect(page).to have_link '« First'
        expect(page).to have_link '‹ Prev'
        expect(page).to have_link '1'
        within '.current' do
          expect(page).to have_text('2')
        end
      end
    end

    it "puts ended relationships at the end" do
      visit entity_path(company)
      # Page 1
      expect(page).not_to have_text(ended_company_1.name)
      expect(page).not_to have_text(ended_company_2.name)

      within('.pagination') { click_link '2' }

      # Page 2
      expect(page).to have_text(ended_company_1.name)
      expect(page).to have_text(ended_company_2.name)
    end
  end

  context 'for a company with multiple owners' do
    include_context 'entity with two owners'

    it 'shows both owners of the company' do
      visit entity_path(company)
      expect(page).to have_text "Beneficial owners of #{company.name}"
      expect(page).to have_text interests_summary(relationship_1)
      expect_beneficial_owner_section_for relationship_1
      expect(page).to have_text interests_summary(relationship_2)
      expect_beneficial_owner_section_for relationship_2

      expect(page).to have_text "No companies are known to be controlled by #{company.name}"
    end

    it 'shows the company for each owner' do
      visit entity_path(person_1)

      expect(page).to have_text "Companies controlled by #{person_1.name}"
      expect_controlled_company_section_for relationship_1

      visit entity_path(person_2)

      expect(page).to have_text "Companies controlled by #{person_2.name}"
      expect_controlled_company_section_for relationship_2
    end
  end

  context 'for an ownership chain with intermediary companies' do
    include_context 'entity with intermediate ownership'

    it 'shows useful info for a company at the start of the chain' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      expect(page).to have_text "Owned via #{intermediate_company_2.name}  → #{intermediate_company_1.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_owner_relationship

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"
    end

    it 'shows useful info for companies in the middle of the chain' do
      visit entity_path(intermediate_company_1)

      expect(page).to have_text "Beneficial owners of #{intermediate_company_1.name}"
      expect(page).to have_text "Owned via #{intermediate_company_2.name}  → #{intermediate_company_1.name}"
      expect_beneficial_owner_section_for intermediate_1_to_owner_relationship

      expect(page).to have_text "Companies controlled by #{intermediate_company_1.name}"
      expect_controlled_company_section_for start_to_intermediate_1_relationship

      visit entity_path(intermediate_company_2)

      expect(page).to have_text "Beneficial owners of #{intermediate_company_2.name}"
      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)
      expect_beneficial_owner_section_for intermediate_2_to_owner_relationship

      expect(page).to have_text "Companies controlled by #{intermediate_company_2.name}"
      expect_controlled_company_section_for intermediate_1_to_intermediate_2_relationship
    end

    it 'shows useful info for the person at the end of the chain' do
      visit entity_path(ultimate_owner)

      expect(page).to have_text "Companies controlled by #{ultimate_owner.name}"
      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)
      expect_controlled_company_section_for intermediate_2_to_owner_relationship
      # We only show directly controlled companies
      expect(page).not_to have_text start_company.name
      expect(page).not_to have_text intermediate_company_1.name
    end
  end

  context 'for a complex ownership network with multiple owners at different levels' do
    include_context 'entity with ownership at different levels'

    it 'shows useful info for a company under both owners' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      expect(page).to have_text interests_summary(start_to_direct_owner_relationship)
      expect_beneficial_owner_section_for start_to_direct_owner_relationship
      expect(page).to have_text "Owned via #{intermediate_company.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_ultimate_owner_relationship

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"
    end

    it 'shows useful info for companies under one owner' do
      visit entity_path(intermediate_company)

      expect(page).to have_text "Beneficial owners of #{intermediate_company.name}"
      expect(page).to have_text interests_summary(intermediate_to_ultimate_owner_relationship)
      expect_beneficial_owner_section_for intermediate_to_ultimate_owner_relationship

      expect(page).to have_text "Companies controlled by #{intermediate_company.name}"
      expect(page).to have_text interests_summary(start_to_intermediate_relationship)
      expect_controlled_company_section_for start_to_intermediate_relationship
    end
  end

  context 'for an ownership chain with no owner at the end' do
    include_context 'entity with no ultimate ownership'

    it 'shows ownership info for all the companies in the chain' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      # Non-ownerships are displayed a bit different to other chains
      within '.ultimate-source-relationships' do
        expect(page).to have_selector '.entity-link', text: 'No person'
        expect(page).not_to have_link 'No person'
        expect(page).to have_link "", href: relationship_href(start_to_no_owner_relationship)
        expect(page).to have_text "Owned via #{intermediate_company.name} → #{start_company.name}"
      end

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"

      visit entity_path(intermediate_company)

      expect(page).to have_text "Beneficial owners of #{intermediate_company.name}"
      # Non-ownerships are displayed a bit different to other chains
      within '.ultimate-source-relationships' do
        expect(page).to have_selector '.entity-link', text: 'No person'
        expect(page).not_to have_link 'No person'
        expect(page).to have_link "", href: relationship_href(intermediate_to_no_owner_relationship)
        expect(page).to have_text 'Interests unknown'
      end

      expect(page).to have_text "Companies controlled by #{intermediate_company.name}"
      expect(page).to have_text interests_summary(start_to_intermediate_relationship)
      expect_controlled_company_section_for start_to_intermediate_relationship
    end
  end

  context "for an ownership chain with an unknown ultimate owner" do
    include_context 'entity with unknown ultimate ownership'

    it 'shows ownership info for all the companies in the chain' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      # Unknown ownerships are displayed a bit different to other chains
      within '.ultimate-source-relationships' do
        expect(page).to have_selector '.entity-link', text: 'Unknown'
        expect(page).not_to have_link 'Unknown'
        expect(page).to have_link "", href: relationship_href(start_to_unknown_owner_relationship)
        expect(page).to have_text "Owned via #{intermediate_company.name} → #{start_company.name}"
      end

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"

      visit entity_path(intermediate_company)

      expect(page).to have_text "Beneficial owners of #{intermediate_company.name}"
      # Non-ownerships are displayed a bit different to other chains
      within '.ultimate-source-relationships' do
        expect(page).to have_selector '.entity-link', text: 'Unknown'
        expect(page).not_to have_link 'Unknown'
        expect(page).to have_link "", href: relationship_href(intermediate_to_unknown_owner_relationship)
        expect(page).to have_text 'Interests unknown'
      end

      expect(page).to have_text "Companies controlled by #{intermediate_company.name}"
      expect(page).to have_text interests_summary(start_to_intermediate_relationship)
      expect_controlled_company_section_for start_to_intermediate_relationship
    end
  end

  context 'for an entity with circular ownership' do
    include_context 'entity with circular ownership'

    it 'shows an unknown ultimate owner for both companies' do
      visit entity_path(company_1)
      expect(page).to have_text "#{company_1.name} has no beneficial owners"

      visit entity_path(company_2)
      expect(page).to have_text "#{company_2.name} has no beneficial owners"
    end

    it 'shows the controlled companies for both companies' do
      visit entity_path(company_1)

      expect(page).to have_text "Companies controlled by #{company_1.name}"
      expect(page).to have_text interests_summary(company_2_to_company_1_relationship)
      expect_controlled_company_section_for company_2_to_company_1_relationship

      visit entity_path(company_2)

      expect(page).to have_text "Companies controlled by #{company_2.name}"
      expect(page).to have_text interests_summary(company_1_to_company_2_relationship)
      expect_controlled_company_section_for company_1_to_company_2_relationship
    end
  end

  context 'for an entity with circular ownership and an ultimate owner' do
    include_context 'entity with circular ownership and an ultimate owner'

    it 'shows the ultimate ownership for each company' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      expect_beneficial_owner_section_for start_to_ultimate_owner_relationship
      expect(page).to have_text "Owned via #{intermediate_company.name} → #{start_company.name}"

      visit entity_path(intermediate_company)

      expect(page).to have_text "Beneficial owners of #{intermediate_company.name}"
      expect_beneficial_owner_section_for intermediate_to_ultimate_owner_relationship
      expect(page).to have_text interests_summary(intermediate_to_ultimate_owner_relationship)
    end

    it 'shows the controlled companies for both companies' do
      visit entity_path(start_company)

      expect(page).to have_text "Companies controlled by #{start_company.name}"
      expect(page).to have_text interests_summary(intermediate_to_start_relationship)
      expect_controlled_company_section_for intermediate_to_start_relationship

      visit entity_path(intermediate_company)

      expect(page).to have_text "Companies controlled by #{intermediate_company.name}"
      expect(page).to have_text interests_summary(start_to_intermediate_relationship)
      expect_controlled_company_section_for start_to_intermediate_relationship
    end
  end

  context 'for an entity with a diamond ownership' do
    include_context 'entity with diamond ownership'

    it 'shows both routes to the owner for the company at the bottom' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      expect(page).to have_text "Owned via #{intermediate_company_1.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_owner_relationship_via_intermediate_1
      expect(page).to have_text "Owned via #{intermediate_company_2.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_owner_relationship_via_intermediate_2

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"
    end

    it 'shows the same info for each company in the middle' do
      visit entity_path(intermediate_company_1)

      expect(page).to have_text "Beneficial owners of #{intermediate_company_1.name}"
      expect_beneficial_owner_section_for intermediate_1_to_owner_relationship
      expect(page).to have_text interests_summary(intermediate_1_to_owner_relationship)

      expect(page).to have_text "Companies controlled by #{intermediate_company_1.name}"
      expect_controlled_company_section_for start_to_intermediate_1_relationship

      visit entity_path(intermediate_company_2)

      expect(page).to have_text "Beneficial owners of #{intermediate_company_2.name}"
      expect_beneficial_owner_section_for intermediate_2_to_owner_relationship
      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)

      expect(page).to have_text "Companies controlled by #{intermediate_company_2.name}"
      expect_controlled_company_section_for start_to_intermediate_2_relationship
    end

    it "shows both intermediate companies for the person at the end of the chain" do
      visit entity_path(ultimate_owner)

      expect(page).to have_text "Companies controlled by #{ultimate_owner.name}"
      expect(page).to have_text interests_summary(intermediate_1_to_owner_relationship)
      expect_controlled_company_section_for intermediate_1_to_owner_relationship

      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)
      expect_controlled_company_section_for intermediate_2_to_owner_relationship

      # We only show directly controlled companies
      expect(page).not_to have_text start_company.name
    end
  end
end
