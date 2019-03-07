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
end
