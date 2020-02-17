require 'rails_helper'

RSpec.describe 'Search results' do
  include EntityHelpers
  include SearchHelpers

  let!(:company) { FactoryGirl.create(:legal_entity) }
  let!(:holding_company) { FactoryGirl.create(:legal_entity) }
  let!(:ceased_company) do
    FactoryGirl.create(:legal_entity, dissolution_date: '2019-01-01')
  end
  let!(:person) { FactoryGirl.create(:natural_person) }
  let!(:holding_relationship) do
    FactoryGirl.create(:relationship, source: holding_company, target: company)
  end
  let!(:relationship) do
    FactoryGirl.create(:relationship, source: person, target: holding_company)
  end

  before do
    Entity.import(force: true, refresh: true)
  end

  it 'displays useful search results' do
    search_for 'Example' # Matches all people and companies

    # Company results
    expect(page).to have_text company.name
    expect(page).to have_text 'United Kingdom'
    # Note UTF-8 hyphens!
    expect(page).to have_text "(#{company.incorporation_date.iso8601} – )"
    expect(page).to have_text "(#{ceased_company.incorporation_date.iso8601} – #{ceased_company.dissolution_date})"
    expect(page).to have_link company.name
    expect(page).to have_link ceased_company.name
    expect(page).to have_link holding_company.name
    expect(page).to have_selector 'img.flag'
    expect(page).to have_selector '.type-icon.legal-entity'

    # Person results
    expect(page).to have_text 'British'
    expect(page).to have_text "Born #{birth_month_year(person)}"
    expect(page).to have_text "Controls: #{holding_company.name}"
    expect(page).to have_link person.name
    expect(page).to have_selector '.type-icon.natural-person'
  end

  it "limits the number of companies listed under a result to 10 current relationships" do
    relationships = create_list(:relationship, 10, source: person)
    # Ended relationships that shouldn't be counted
    create_list(:relationship, 10, source: person, started_date: '2019-07-01', ended_date: '2019-07-21')

    search_for person.name

    relationships.first(8).each do |relationship|
      within '.result-controls' do
        expect(page).to have_link relationship.target.name
      end
    end

    within '.result-controls' do
      expect(page).to have_link '1 more'
    end
  end

  context "when search results have merged people" do
    let(:merged_people) { create_list(:natural_person, 3) }

    before do
      person.merged_entities << merged_people
    end

    it "shows how many people have been merged together for each result" do
      search_for 'Example' # Matches all people and companies

      expect(page).to have_text 'Includes details of 3 other merged records'
    end
  end
end
