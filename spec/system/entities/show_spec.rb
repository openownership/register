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
      expect(page).to have_link 'View as graph'

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
      expect(page).to have_link 'View as graph'

      expect(page).not_to have_text "Beneficial owners of #{person.name}"

      expect(page).to have_text "Companies controlled by #{person.name}"
      expect_controlled_company_section_for relationship
    end
  end

  context 'for a company that owns lots of others' do
    include_context 'basic entity with one owner'

    let!(:relationships) do
      relationships = []
      (1...13).each do |i|
        relationships << FactoryBot.create(:relationship, source: company, started_date: i.day.ago.to_date.iso8601)
      end
      relationships
    end

    it 'paginates the list of owned companies' do
      visit entity_path(company)
      expect(page).to have_text 'Displaying companies 1 - 10 of 12 in total'

      expect(page).not_to have_text relationships.last.target.name
      expect(page).not_to have_text relationships[-2].target.name

      within '.source-relationships .pagination' do
        within '.current' do
          expect(page).to have_text('1')
        end
        expect(page).to have_link '2'
        expect(page).to have_link 'Next ›'
        expect(page).to have_link 'Last »'
        click_link '2'
      end

      expect(page).to have_text relationships.last.target.name
      expect(page).to have_text relationships[-2].target.name

      expect(page).not_to have_text relationships.first.target.name
      expect(page).not_to have_text relationships.second.target.name

      within '.source-relationships .pagination' do
        expect(page).to have_link '« First'
        expect(page).to have_link '‹ Prev'
        expect(page).to have_link '1'
        within '.current' do
          expect(page).to have_text('2')
        end
      end
    end
  end

  context 'for a company with multiple owners' do
    include_context 'entity with two owners'

    it 'shows both owners of the company' do
      visit entity_path(company)
      expect(page).to have_text "Beneficial owners of #{company.name}"
      expect(page).to have_text interests_summary(relationship1)
      expect_beneficial_owner_section_for relationship1
      expect(page).to have_text interests_summary(relationship2)
      expect_beneficial_owner_section_for relationship2

      expect(page).to have_text "No companies are known to be controlled by #{company.name}"
    end

    it 'shows the company for each owner' do
      visit entity_path(person1)

      expect(page).to have_text "Companies controlled by #{person1.name}"
      expect_controlled_company_section_for relationship1

      visit entity_path(person2)

      expect(page).to have_text "Companies controlled by #{person2.name}"
      expect_controlled_company_section_for relationship2
    end
  end

  context 'for an ownership chain with intermediary companies' do
    include_context 'entity with intermediate ownership'

    it 'shows useful info for a company at the start of the chain' do
      visit entity_path(start_company)

      expect(page).to have_text "Beneficial owners of #{start_company.name}"
      expect(page).to have_text "Owned via #{intermediate_company2.name} → #{intermediate_company1.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_owner_relationship

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"
    end

    it 'shows useful info for companies in the middle of the chain' do
      visit entity_path(intermediate_company1)

      expect(page).to have_text "Beneficial owners of #{intermediate_company1.name}"
      expect(page).to have_text "Owned via #{intermediate_company2.name} → #{intermediate_company1.name}"
      expect_beneficial_owner_section_for intermediate_1_to_owner_relationship

      expect(page).to have_text "Companies controlled by #{intermediate_company1.name}"
      expect_controlled_company_section_for start_to_intermediate_1_relationship

      visit entity_path(intermediate_company2)

      expect(page).to have_text "Beneficial owners of #{intermediate_company2.name}"
      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)
      expect_beneficial_owner_section_for intermediate_2_to_owner_relationship

      expect(page).to have_text "Companies controlled by #{intermediate_company2.name}"
      expect_controlled_company_section_for intermediate_1_to_intermediate_2_relationship
    end

    it 'shows useful info for the person at the end of the chain' do
      visit entity_path(ultimate_owner)

      expect(page).to have_text "Companies controlled by #{ultimate_owner.name}"
      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)
      expect_controlled_company_section_for intermediate_2_to_owner_relationship
      # We only show directly controlled companies
      expect(page).not_to have_text start_company.name
      expect(page).not_to have_text intermediate_company1.name
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
      visit entity_path(company1)
      expect(page).to have_text "#{company1.name} has no beneficial owners"

      visit entity_path(company2)
      expect(page).to have_text "#{company2.name} has no beneficial owners"
    end

    it 'shows the controlled companies for both companies' do
      visit entity_path(company1)

      expect(page).to have_text "Companies controlled by #{company1.name}"
      expect(page).to have_text interests_summary(company2_to_company1_relationship)
      expect_controlled_company_section_for company2_to_company1_relationship

      visit entity_path(company2)

      expect(page).to have_text "Companies controlled by #{company2.name}"
      expect(page).to have_text interests_summary(company1_to_company2_relationship)
      expect_controlled_company_section_for company1_to_company2_relationship
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
      expect(page).to have_text "Owned via #{intermediate_company1.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_owner_relationship_via_intermediate1
      expect(page).to have_text "Owned via #{intermediate_company2.name} → #{start_company.name}"
      expect_beneficial_owner_section_for start_to_owner_relationship_via_intermediate2

      expect(page).to have_text "No companies are known to be controlled by #{start_company.name}"
    end

    it 'shows the same info for each company in the middle' do
      visit entity_path(intermediate_company1)

      expect(page).to have_text "Beneficial owners of #{intermediate_company1.name}"
      expect_beneficial_owner_section_for intermediate_1_to_owner_relationship
      expect(page).to have_text interests_summary(intermediate_1_to_owner_relationship)

      expect(page).to have_text "Companies controlled by #{intermediate_company1.name}"
      expect_controlled_company_section_for start_to_intermediate_1_relationship

      visit entity_path(intermediate_company2)

      expect(page).to have_text "Beneficial owners of #{intermediate_company2.name}"
      expect_beneficial_owner_section_for intermediate_2_to_owner_relationship
      expect(page).to have_text interests_summary(intermediate_2_to_owner_relationship)

      expect(page).to have_text "Companies controlled by #{intermediate_company2.name}"
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

  context 'for a person that has lots of merged people' do
    include_context 'basic entity with one owner'

    let!(:merged_people) { create_list(:natural_person, 12, master_entity: person) }

    it 'paginates the merged people list' do
      visit entity_path(person)
      expect(page).to have_text 'Displaying merged people 1 - 10 of 12 in total'

      expect(page).not_to have_text merged_people.last.name
      expect(page).not_to have_text merged_people[-2].name

      within '.merged-people .pagination' do
        within '.current' do
          expect(page).to have_text('1')
        end
        expect(page).to have_link '2'
        expect(page).to have_link 'Next ›'
        expect(page).to have_link 'Last »'
        click_link '2'
      end

      expect(page).to have_text merged_people.last.name
      expect(page).to have_text merged_people[-2].name

      expect(page).not_to have_text merged_people.first.name
      expect(page).not_to have_text merged_people.second.name

      within '.merged-people .pagination' do
        expect(page).to have_link '« First'
        expect(page).to have_link '‹ Prev'
        expect(page).to have_link '1'
        within '.current' do
          expect(page).to have_text('2')
        end
      end
    end
  end

  context 'for a person that owns lots of companies and has lots of merged people' do
    include_context 'basic entity with one owner'

    let!(:relationships) do
      relationships = []
      (1...13).each do |i|
        relationships << FactoryBot.create(:relationship, source: person, started_date: i.day.ago.to_date.iso8601)
      end
      relationships
    end

    let!(:merged_people) { create_list(:natural_person, 12, master_entity: person) }

    it 'paginates the merged people and companies lists separately' do
      visit entity_path(person)
      expect(page).to have_text 'Displaying merged people 1 - 10 of 12 in total'
      expect(page).to have_text 'Displaying companies 1 - 10 of 13 in total'

      expect(page).not_to have_text merged_people.last.name
      expect(page).not_to have_text merged_people[-2].name
      expect(page).not_to have_text relationships.last.target.name
      expect(page).not_to have_text relationships[-2].target.name

      within '.merged-people .pagination' do
        click_link '2'
      end

      expect(page).to have_text merged_people.last.name
      expect(page).to have_text merged_people[-2].name
      expect(page).not_to have_text relationships.last.target.name
      expect(page).not_to have_text relationships[-2].target.name

      within '.source-relationships .pagination' do
        click_link '2'
      end

      expect(page).to have_text merged_people.last.name
      expect(page).to have_text merged_people[-2].name
      expect(page).to have_text relationships.last.target.name
      expect(page).to have_text relationships[-2].target.name
    end
  end

  context 'when the entity has raw data provenance' do
    include_context 'basic entity with one owner'

    let(:data_source1) { create(:data_source, name: 'Data Source 1') }
    let(:data_source2) { create(:data_source, name: 'Data Source 2') }
    let(:oldest) { 10.days.ago }
    let(:newest) { 1.day.ago }
    let(:import1) do
      import = create(:import, data_source: data_source1)
      import.timeless.update_attribute(:created_at, oldest)
      import
    end
    let(:import2) do
      import = create(:import, data_source: data_source2)
      import.timeless.update_attribute(:created_at, newest)
      import
    end

    let!(:import1_provenances) do
      create_list(:raw_data_provenance, 5, entity_or_relationship: company, import: import1)
    end
    let!(:import2_provenances) do
      create_list(:raw_data_provenance, 5, entity_or_relationship: company, import: import2)
    end

    it 'shows a provenance box with a summary and a link to the raw data page' do
      visit entity_path(company)

      expect(page).to have_text('Provenance')
      expect(page).to have_text('Data Source 1 and Data Source 2')
      expected_date = import2_provenances.last.raw_data_records.last.updated_at.to_date
      expect(page).to have_text("Latest data: #{expected_date}")
      expect(page).to have_link("See the 20 original source records")
    end
  end

  context 'when the entity has no raw data provenance' do
    include_context 'basic entity with one owner'

    it "doesn't show a provenance box" do
      visit entity_path(company)
      expect(page).not_to have_text('Provenance')
    end
  end
end
