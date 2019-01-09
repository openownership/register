require 'rails_helper'

RSpec.describe 'edit interests' do
  let(:submission) { create(:submission) }

  before do
    login_as submission.user
    create(
      :submission_relationship,
      submission: submission,
      target: create(:submission_legal_entity, submission: submission),
      source: create(:submission_natural_person, submission: submission),
      ownership_of_shares_percentage: 20.0,
    )
  end

  scenario 'successfully' do
    visit edit_submission_path(submission)
    click_on edit_interests_button
    fill_in 'relationship_ownership_of_shares_percentage', with: '30.0'
    check 'relationship_right_to_appoint_and_remove_directors'
    click_on continue_button
    expect(page).to have_text ownership_of_shares(30.0)
    expect(page).to have_text right_to_appoint_and_remove_directors
  end

  def edit_interests_button
    I18n.t('submissions.submissions.tree_node.edit_interests')
  end

  def continue_button
    I18n.t('submissions.relationships.form.continue')
  end

  def ownership_of_shares(value)
    I18n.t('submissions.relationships.interests.ownership_of_shares_percentage', value: value)
  end

  def right_to_appoint_and_remove_directors
    I18n.t('submissions.relationships.interests.right_to_appoint_and_remove_directors')
  end
end
