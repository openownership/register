require 'rails_helper'

RSpec.describe 'Viewing an entity' do
  include EntityHelpers
  include_context 'basic entity with stubbed OC api'

  it 'shows useful info for a company' do
    visit entity_path(company)

    expect(page).to have_text "Beneficial owners of #{company.name}"
    expect(page).to have_text company.incorporation_date.iso8601
    expect(page).to have_text company.company_number
    expect(page).to have_text "No companies are known to be controlled by #{company.name}"
    expect(page).to have_link 'Google'
    expect(page).to have_link 'Report incorrect data'
    expect(page).to have_link 'View as tree'

    expect(page).to have_text person.name
    expect(page).to have_text "Born #{birth_month_year(person)}"
    expect(page).to have_link relationship_link(relationship), href: relationship_href(relationship)
  end

  it 'shows useful info for a person' do
    visit entity_path(person)

    expect(page).to have_text "Companies controlled by #{person.name}"
    expect(page).to have_text person.address
    expect(page).to have_text 'British'
    expect(page).to have_text person.nationality
    expect(page).to have_text birth_month_year(person)
    expect(page).to have_text "Companies controlled by #{person.name} #{company.name}"
    expect(page).to have_link 'Google'
    expect(page).to have_link 'Report incorrect data'

    expect(page).to have_text company.incorporation_date.iso8601
    expect(page).to have_link relationship_link(relationship), href: relationship_href(relationship)
    expect(page).to have_text ownership_summary(relationship)
  end
end
