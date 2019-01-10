require 'rails_helper'

RSpec.describe 'My account' do
  include UserHelpers

  let(:user) { FactoryGirl.create(:user) }
  let(:new_email) { 'new-email@example.com' }

  it 'can change email address' do
    visit '/'
    click_link 'Sign in'
    signin_as user
    click_link 'My account'
    fill_in 'Email', with: new_email
    fill_in 'Current password', with: user.password
    click_button 'Update'
    expect(page).to have_text confirm_email_change_message
    open_email new_email
    current_email.click_link 'Confirm my account'
    expect(page).to have_text email_change_confirmed_message
  end

  it 'can change password' do
    visit '/'
    click_link 'Sign in'
    signin_as user
    click_link 'My account'
    fill_in 'Password', with: "#{user.password}_1"
    fill_in 'Current password', with: user.password
    click_button 'Update'
    expect(page).to have_text account_updated_message
  end

  def confirm_email_change_message
    I18n.t('devise.registrations.update_needs_confirmation')
  end

  def email_change_confirmed_message
    I18n.t('devise.confirmations.confirmed')
  end

  def account_updated_message
    I18n.t('devise.registrations.updated')
  end
end
