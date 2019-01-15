require 'rails_helper'

RSpec.describe 'Tree view' do
  include EntityHelpers
  include_context 'basic entity with stubbed OC api'

  it 'can view the beneficial owners as a tree' do
    visit url_for(company)
    click_link 'View as tree'

    expect(page).to have_css('.tree-node--natural-person', text: person.name)
    within('.tree-node--natural-person') do
      expect(page).to have_link person.name
    end

    expect(page).to have_css('.tree-node__relationship', text: ownership_summary(relationship))

    expect(page).to have_css('.tree-node--root', text: company.name)
    within('.tree-node--root') do
      expect(page).to have_link company.name
    end
  end
end
