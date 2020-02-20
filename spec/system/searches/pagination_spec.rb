require 'rails_helper'

RSpec.describe 'Search pagination' do
  include SearchHelpers

  let!(:companies) { FactoryGirl.create_list(:legal_entity, 20) }
  let!(:people) { FactoryGirl.create_list(:natural_person, 20) }

  before do
    Entity.import(force: true, refresh: true)
  end

  it 'can page through results' do
    search_for 'Example' # Matches all people and companies

    expect(page).to have_selector('.list-entities .item', count: 10)
    expect(page).to have_text 'Displaying results 1 - 10 of 40 in total'

    within '.pagination' do
      within '.current' do
        expect(page).to have_text('1')
      end

      expect(page).to have_link '2'
      expect(page).to have_link '3'
      expect(page).to have_link '4'
      expect(page).to have_link 'Next ›'
      expect(page).to have_link 'Last »'

      click_link '3'
    end

    within '.pagination' do
      expect(page).to have_link '« First'
      expect(page).to have_link '‹ Prev'
      expect(page).to have_link '1'
      expect(page).to have_link '2'
      within '.current' do
        expect(page).to have_text('3')
      end
      expect(page).to have_link '4'
      expect(page).to have_link 'Next ›'
      expect(page).to have_link 'Last »'

      click_link 'Last »'
    end

    within '.pagination' do
      expect(page).to have_link '« First'
      expect(page).to have_link '‹ Prev'
      expect(page).to have_link '1'
      expect(page).to have_link '2'
      expect(page).to have_link '3'
      within '.current' do
        expect(page).to have_text('4')
      end
    end
  end
end
