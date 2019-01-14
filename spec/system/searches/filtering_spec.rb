require 'rails_helper'

RSpec.describe 'Filtering search results' do
  let!(:uk_company) { FactoryGirl.create(:legal_entity) }
  let!(:australian_company) { FactoryGirl.create(:legal_entity, jurisdiction_code: 'au') }
  let!(:uk_person) { FactoryGirl.create(:natural_person) }
  let!(:australian_person) { FactoryGirl.create(:natural_person, nationality: 'au') }

  before do
    Entity.import(force: true, refresh: true)
  end

  it 'Can filter results by entity type' do
    visit '/'
    within '.search-content' do
      fill_in 'q', with: 'Example' # Matches all people and companies
      click_button 'Search'
    end

    click_link 'Person', href: %r{\/search\/*}
    expect(page).to have_text uk_person.name
    expect(page).to have_text australian_person.name
    expect(page).not_to have_text uk_company.name
    expect(page).not_to have_text australian_company.name

    click_link 'Remove filter'
    expect(page).to have_text uk_person.name
    expect(page).to have_text australian_person.name
    expect(page).to have_text uk_company.name
    expect(page).to have_text australian_company.name
  end

  it 'Can filter results by country' do
    visit '/'
    within '.search-content' do
      fill_in 'q', with: 'Example' # Matches all people and companies
      click_button 'Search'
    end

    click_link 'Australia', href: %r{\/search\/*}
    expect(page).to have_text australian_company.name
    expect(page).to have_text australian_person.name
    expect(page).not_to have_text uk_person.name
    expect(page).not_to have_text uk_company.name

    click_link 'Remove filter'
    expect(page).to have_text uk_person.name
    expect(page).to have_text australian_person.name
    expect(page).to have_text uk_company.name
    expect(page).to have_text australian_company.name
  end
end
