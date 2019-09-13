require 'rails_helper'

RSpec.describe 'the data download message' do
  it 'shows up on first load, can be dismissed and stays dismissed until cookies are cleared', js: true do
    visit '/'

    within('.data-download-alert') do
      expect(page).to have_text "Bulk downloads are coming soon"
      expect(page).to have_link("Register to be notified when they're available", href: 'https://docs.google.com/forms/d/1V5uxFmXPPGGHB2sJsHbuHxzl0INNq_riMtNV-U3swIs')
      click_button('×')
    end

    expect(page).not_to have_text "Bulk downloads are coming soon"

    visit '/'
    expect(page).not_to have_text "Bulk downloads are coming soon"

    Capybara.reset!

    visit '/'

    within('.data-download-alert') do
      expect(page).to have_text "Bulk downloads are coming soon"
    end
  end
end
