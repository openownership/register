require 'rails_helper'

RSpec.feature 'insert company' do
  include SubmissionHelpers

  let(:submission) { create(:submission) }

  before do
    stub_opencorporates_api_for_search
    login_as submission.user
  end

  context 'below an entity in the tree' do
    before do
      create(
        :submission_relationship,
        submission: submission,
        source: create(:submission_natural_person, submission: submission),
        target: create(:submission_legal_entity, submission: submission),
      )
    end

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on insert_company_below_button
      fill_in 'search_q', with: 'Acme Corporation'
      click_on submit_button
      click_on 'Acme Corporation'
      expect(page).to have_text 'Acme Corporation'
    end
  end

  context 'above an entity in the tree' do
    before do
      root = create(:submission_legal_entity, submission: submission)

      create(
        :submission_relationship,
        submission: submission,
        source: create(:submission_natural_person, submission: submission),
        target: root,
      )

      create(
        :submission_relationship,
        submission: submission,
        source: create(:submission_natural_person, submission: submission),
        target: root,
      )
    end

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on insert_company_above_button
      fill_in 'search_q', with: 'Acme Corporation'
      click_on submit_button
      click_on 'Acme Corporation'
      expect(page).to have_text 'Acme Corporation'
    end
  end

  def insert_company_below_button
    I18n.t('submissions.submissions.tree_node.insert_company_below')
  end

  def insert_company_above_button
    I18n.t('submissions.submissions.tree_node.insert_company_above')
  end

  def submit_button
    I18n.t('submissions.entities.search.submit')
  end
end
