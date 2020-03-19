require 'rails_helper'

RSpec.describe 'complete submission' do
  include SubmissionHelpers

  before do
    stub_opencorporates_api_for_search
    login_as create(:user)
  end

  scenario 'successfully' do
    visit submissions_path
    click_on start_submission_button
    fill_in 'search_q', with: 'Acme Corporation'
    click_on search_button
    click_on create_company_button
    fill_in 'entity_name', with: 'Acme Corporation'
    fill_in 'entity_company_number', with: '1234567890'
    select 'United Kingdom', from: 'entity_jurisdiction_code'
    fill_in 'entity_incorporation_date', with: '1987-09-27'
    fill_in 'entity_address', with: '123 Example Road, AB1 2XY'
    click_on continue_button_for_company
    click_on add_controlling_entity_button
    click_on natural_person_button
    fill_in 'entity_name', with: 'Example Person'
    fill_in 'entity_dob', with: '1950-01-01'
    select 'Argentina', from: 'entity_country_of_residence'
    select 'United Kingdom', from: 'entity_nationality'
    fill_in 'entity_address', with: '123 Example Road, AB1 2XY'
    click_on continue_button_for_person
    click_on add_interests_button
    fill_in 'relationship_ownership_of_shares_percentage', with: '20.0'
    click_on continue_button_for_relationship
    click_on submit_button
    expect(page).to have_text(success_notice)
    open_email(admin_email)
    expect(current_email.subject).to have_text(email_subject)
    expect(current_email.body).to have_link(approve_link)
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

  def continue_button_for_company
    I18n.t('submissions.entities.legal_entity_form.continue')
  end

  def add_controlling_entity_button
    I18n.t('submissions.submissions.tree_node.add_controlling_entity')
  end

  def natural_person_button
    I18n.t('submissions.entities.choose.add_natural_person')
  end

  def continue_button_for_person
    I18n.t('submissions.entities.natural_person_form.continue')
  end

  def add_interests_button
    I18n.t('submissions.submissions.tree_node.add_interests')
  end

  def continue_button_for_relationship
    I18n.t('submissions.relationships.form.continue')
  end

  def submit_button
    I18n.t('submissions.submissions.instructions_steps.submit')
  end

  def success_notice
    I18n.t('submissions.submissions.submit.success', entity: 'Acme Corporation')
  end

  def admin_email
    ENV['ADMIN_EMAILS'].split(',').first
  end

  def email_subject
    I18n.t('submission_mailer.submission_approval_requested.subject')
  end

  def approve_link
    I18n.t('submission_mailer.submission_approval_requested.view')
  end
end
