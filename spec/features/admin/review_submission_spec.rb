require 'rails_helper'

RSpec.feature 'review submission' do
  include AdminHelpers

  let!(:submission) { create(:submitted_submission) }

  before do
    page.driver.header('Authorization', admin_basic_auth)
    stub_elasticsearch
    stub_opencorporates_client_get_company
    stub_opencorporates_client_search_companies
  end

  scenario 'approve' do
    visit admin_submissions_path
    click_on submission.entity.name
    click_on approve_button
    expect(page).to have_text(success_notice)
    expect(last_delivered_email.subject).to eq(submission_approved_subject)
  end

  def approve_button
    I18n.t('admin.submissions.show.approve')
  end

  def success_notice
    I18n.t('admin.submissions.approve.success', entity: submission.entity.name)
  end

  def last_delivered_email
    ActionMailer::Base.deliveries.last
  end

  def submission_approved_subject
    I18n.t('submission_mailer.submission_approved.subject')
  end
end
