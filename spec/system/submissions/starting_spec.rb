require 'rails_helper'

RSpec.describe 'starting submission' do
  include SubmissionHelpers
  let(:user) { create(:user) }

  before do
    stub_opencorporates_api_for_search
    login_as user
  end

  scenario 'restarting search' do
    visit submissions_path
    click_on start_submission_button
    fill_in 'search_q', with: 'Acme Corporation'
    click_on search_button
    click_on create_company_button

    submission = user.submissions.first
    visit edit_submission_path(submission)

    expect(page).to have_text search_for_a_company_header

    visit submission_path(submission)

    expect(page).to have_text search_for_a_company_header
  end

  def start_submission_button
    I18n.t('submissions.submissions.index.start_submission')
  end

  def search_button
    I18n.t('submissions.entities.search.submit')
  end

  def create_company_button
    I18n.t('submissions.entities.search.create_company')
  end

  def search_for_a_company_header
    I18n.t('submissions.entities.search.search_for_a_company')
  end
end
