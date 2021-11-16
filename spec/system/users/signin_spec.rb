require 'rails_helper'

RSpec.describe 'User signin' do
  include UserHelpers

  let(:user) { FactoryBot.create(:user) }

  it 'can sign in' do
    visit '/'
    click_link 'Sign in'
    signin_as user
    expect(page).to have_text(signin_success_message)
    expect(page).to have_link('My account')
  end

  it 'can reset password and is then signed in' do
    visit '/'
    click_link 'Sign in'
    click_link forgot_password
    fill_in 'Email', with: user.email
    click_button send_reset_instructions
    open_email(user.email)
    current_email.click_link('Change my password')
    fill_in 'New password', with: "#{user.password}_1"
    click_button 'Change my password'
    expect(page).to have_text(password_reset_success_message)
    expect(page).to have_link('My account')
  end

  def forgot_password
    I18n.t('devise.shared.links.new_password')
  end

  def send_reset_instructions
    I18n.t('devise.passwords.new.submit')
  end

  def password_reset_success_message
    I18n.t('devise.passwords.updated')
  end
end
