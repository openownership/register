require 'rails_helper'

RSpec.describe 'review submission' do
  include AdminHelpers

  let!(:submission) { create(:submitted_submission) }

  before do
    page.driver.header('Authorization', admin_basic_auth)
    stub_elasticsearch
    stub_opencorporates_client_get_company
    stub_opencorporates_client_search_companies
    SubmissionMailer.submission_approval_requested(submission).deliver_now
  end

  scenario 'approve through admin dashboard' do
    visit admin_submissions_path
    click_on submission.entity.name
    click_on approve_button
    open_email(submission.user.email)
    expect(current_email.subject).to eq(submission_approved_subject)
  end

  scenario 'approve through email notification' do
    open_email admin_email
    current_email.click_link approve_link
    click_on approve_button
    expect(page).to have_text(success_notice)
    open_email(submission.user.email)
    expect(current_email.subject).to eq(submission_approved_subject)
  end

  def approve_button
    I18n.t('admin.submissions.show.approve')
  end

  def success_notice
    I18n.t('admin.submissions.approve.success', entity: submission.entity.name)
  end

  def submission_approved_subject
    I18n.t('submission_mailer.submission_approved.subject')
  end

  def admin_email
    ENV['ADMIN_EMAILS'].split(',').first
  end

  def approve_link
    I18n.t('submission_mailer.submission_approval_requested.view')
  end
end
