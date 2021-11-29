require 'rails_helper'

RSpec.describe 'User signup' do
  include UserHelpers

  let(:user) { FactoryBot.build(:user) }

  it 'can sign up for an account and sign in' do
    visit '/'
    click_link 'Sign up'
    signup_as user
    expect(page).to have_text(signup_success_message)
    open_email(user.email)
    current_email.click_link 'Confirm my account'
    expect(page).to have_text(confirmation_success_message)
    signin_as user
    expect(page).to have_text(signin_success_message)
    expect(page).to have_link('My account')
  end

  it 'can resend email confirmation during signup' do
    visit '/'
    click_link 'Sign up'
    signup_as user
    expect(page).to have_text(signup_success_message)
    click_link 'Sign in'
    click_link didnt_receive_confirmation
    fill_in 'Email', with: user.email
    click_button resend_confirmation
    expect(emails_sent_to(user.email).length).to eq(2)
    open_email(user.email)
    current_email.click_link('Confirm my account')
    expect(page).to have_text(confirmation_success_message)
    signin_as user
    expect(page).to have_text(signin_success_message)
    expect(page).to have_link('My account')
  end

  def signup_as(user)
    fill_in 'Name', with: user.name
    fill_in 'Company name', with: user.company_name
    fill_in 'Position', with: user.position
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Sign up'
  end

  def confirmation_success_message
    I18n.t('devise.confirmations.confirmed')
  end

  def signup_success_message
    I18n.t('devise.registrations.signed_up_but_unconfirmed')
  end

  def didnt_receive_confirmation
    I18n.t('devise.shared.links.new_confirmation')
  end

  def resend_confirmation
    I18n.t('devise.confirmations.new.submit')
  end
end
