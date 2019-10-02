require 'rails_helper'

RSpec.describe 'the data download message' do
  it 'shows up on first load, can be dismissed and stays dismissed until cookies are cleared', js: true do
    visit '/'

    within('.data-download-alert') do
      expect(page).to have_text "Bulk downloads are here"
      expect(page).to have_link("Read our documentation", href: download_path)
      click_button('×')
    end

    expect(page).not_to have_text "Bulk downloads are here"

    visit '/'
    expect(page).not_to have_text "Bulk downloads are here"

    Capybara.reset!

    visit '/'

    within('.data-download-alert') do
      expect(page).to have_text "Bulk downloads are here"
    end
  end
end
