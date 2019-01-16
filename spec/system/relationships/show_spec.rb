require 'rails_helper'

RSpec.describe 'Viewing a relationship' do
  include EntityHelpers
  include_context 'basic entity with stubbed OC api'

  it 'shows useful info for a relationship' do
    visit entity_relationship_path(relationship.target, relationship.source)

    expect(page).to have_text "Beneficial ownership chain: #{person.name} to #{company.name}"

    expect(page).to have_text company.name
    expect(page).to have_text company.incorporation_date.iso8601
    expect(page).to have_text 'United Kingdom'

    expect(page).to have_text person.name
    expect(page).to have_text 'British'
    expect(page).to have_text "Born #{birth_month_year(person)}"

    expect(page).to have_text ownership_summary(relationship)

    expect(page).to have_link relationship.provenance.source_name, href: relationship.provenance.source_url
    expect(page).to have_text "Retrieved: #{relationship_retrieved}"

    expect(page).to have_link 'Report incorrect data'
  end

  def relationship_retrieved
    relationship.provenance.retrieved_at.to_date.iso8601
  end
end
