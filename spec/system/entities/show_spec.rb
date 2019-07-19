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
      relationships = FactoryGirl.create_list(
        :relationship,
        12,
        source: company,
        interests: ['ownership-of-shares-75-to-100-percent'],
      )
      # Need to sort them the same way as the view to test what is/isn't on
      # each page
      RelationshipsSorter.new(relationships).call
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
      expect(page).to have_text 'Displaying companies 1 - 10 of 14 in total'

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

  context 'for two people owning the same company merged into one' do
    include_context 'two people owning the same company merged into one'

    it 'redirects from the merged person to the master person' do
      visit entity_path(person_2)

      expect(current_path).to eq(entity_path(person_1))
    end

    it 'shows the details of people who are merged into the master person' do
      visit entity_path(person_1)

      expect(page).to have_text 'Merged people'
      expect(page).to have_text 'This person has been merged because'
      within '.merged-people' do
        expect(page).to have_text person_2.name
        expect(page).to have_text("Controls: #{company.name}")
      end
    end

    context 'when both people have the same interests' do
      before do
        person_1_relationship.interests << 'ownership-of-shares-75-to-100-percent'
        person_1_relationship.save!
        person_2_relationship.interests << 'ownership-of-shares-75-to-100-percent'
        person_2_relationship.save!
      end

      it 'shows a single person as the ultimate owner of the company' do
        visit entity_path(company)

        expect(page).to have_text "Beneficial owners of #{company.name}"
        expect_beneficial_owner_section_for person_1_relationship
        expect(page).to have_text interests_summary(person_1_relationship)
        within '.ultimate-source-relationships' do
          expect(page).not_to have_text person_2.name
        end

        visit entity_path(person_1)

        expect(page).to have_text "Companies controlled by #{person_1.name}"
        expect(page).to have_text interests_summary(person_1_relationship)
        expect_controlled_company_section_for person_1_relationship
      end
    end

    context "when the people have different interests" do
      before do
        person_1_relationship.interests << 'ownership-of-shares-75-to-100-percent'
        person_1_relationship.save!
        person_2_relationship.interests << 'voting-rights-75-to-100-percent'
        person_2_relationship.save!
      end

      it 'shows two people grouped together by name with separate interests' do
        visit entity_path(company)

        expect(page).to have_text "Beneficial owners of #{company.name}"
        expect_beneficial_owner_section_for person_1_relationship
        expect_beneficial_owner_section_for person_2_relationship
        expect(page).to have_text interests_summary(person_1_relationship)
        expect(page).to have_text interests_summary(person_2_relationship)
        expect(page).to have_text 'These owners have been grouped together'

        within '.ultimate-source-relationships' do
          expect(page).not_to have_text person_2.name
        end
      end
    end
  end

  context 'for two people owning the two different companies merged into one' do
    include_context 'two people owning the two different companies merged into one'

    it 'shows a single person as the ultimate owner of both companies' do
      visit entity_path(company_1)

      expect(page).to have_text "Beneficial owners of #{company_1.name}"
      expect_beneficial_owner_section_for person_1_relationship
      expect(page).to have_text interests_summary(person_1_relationship)

      expect(page).not_to have_text person_2.name

      visit entity_path(company_2)

      expect(page).to have_text "Beneficial owners of #{company_2.name}"
      within '.ultimate-source-relationships' do
        expect(page).to have_selector '.entity-link', text: person_1.name
        expect(page).to have_link person_1.name
        expect(page).to have_selector '.entity-link', text: "Born #{birth_month_year(person_1)}"
      end
      expect(page).to have_text interests_summary(person_2_relationship)

      expect(page).not_to have_text person_2.name

      visit entity_path(person_1)

      expect(page).to have_text "Companies controlled by #{person_1.name}"
      expect(page).to have_selector '.entity-link', text: company_1.name
      expect(page).to have_link company_1.name
      expect(page).to have_selector '.entity-link', text: company_1.incorporation_date.iso8601
      expect(page).to have_selector '.entity-link', text: company_2.name
      expect(page).to have_link company_2.name
      expect(page).to have_selector '.entity-link', text: company_2.incorporation_date.iso8601
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
      relationships = FactoryGirl.create_list(
        :relationship,
        12,
        source: person,
        interests: ['ownership-of-shares-75-to-100-percent'],
      )
      # Need to sort them the same way as the view to test what is/isn't on
      # each page
      RelationshipsSorter.new(relationships).call
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
end
