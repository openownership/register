require 'rails_helper'

RSpec.describe 'add controlling entity' do
  include SubmissionHelpers

  let(:submission) { create(:submission) }

  before do
    stub_opencorporates_api_for_search
    login_as submission.user
  end

  context 'to root entity' do
    before do
      create(:submission_legal_entity, submission: submission)
    end

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on add_controlling_entity_button
      click_on legal_entity_button
      fill_in 'search_q', with: 'Acme Corporation'
      click_on submit_button
      click_on 'Acme Corporation'
      expect(page).to have_text 'Acme Corporation'
    end
  end

  context 'to non-root entity' do
    before do
      create(
        :submission_relationship,
        submission: submission,
        target: create(:submission_legal_entity, submission: submission),
        source: create(:submission_legal_entity, submission: submission),
      )
    end

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on add_controlling_entity_button
      click_on legal_entity_button
      fill_in 'search_q', with: 'Acme Corporation'
      click_on submit_button
      click_on 'Acme Corporation'
      expect(page).to have_text 'Acme Corporation'
    end
  end

  def add_controlling_entity_button
    I18n.t('submissions.submissions.tree_node.add_controlling_entity')
  end

  def legal_entity_button
    I18n.t('submissions.entities.choose.add_legal_entity')
  end

  def submit_button
    I18n.t('submissions.entities.search.submit')
  end
end
