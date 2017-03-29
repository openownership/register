require 'rails_helper'

RSpec.feature 'add sibling entity' do
  include SubmissionHelpers

  let(:submission) { create(:submission) }

  before do
    stub_opencorporates_api_for_search
    login_as submission.user
    create(
      :submission_relationship,
      submission: submission,
      source: create(:submission_natural_person, submission: submission),
      target: create(:submission_legal_entity, submission: submission)
    )
  end

  scenario 'successfully' do
    visit edit_submission_path(submission)
    click_on add_sibling_entity_button, match: :first
    click_on legal_entity_button
    fill_in 'search_q', with: 'Acme Corporation'
    click_on submit_button
    click_on 'Acme Corporation'
    expect(page).to have_text 'Acme Corporation'
  end

  def add_sibling_entity_button
    I18n.t('submissions.submissions.tree_node.add_sibling_entity')
  end

  def legal_entity_button
    I18n.t('submissions.entities.choose.add_legal_entity')
  end

  def submit_button
    I18n.t('submissions.entities.search.submit')
  end
end
