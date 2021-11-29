require 'rails_helper'

RSpec.describe 'User signout' do
  include UserHelpers

  let(:user) { FactoryBot.create(:user) }

  it 'can signout' do
    visit '/'
    click_link 'Sign in'
    signin_as user
    click_link 'Sign out'
    expect(page).to have_text signout_message
  end

  def signout_message
    I18n.t('devise.sessions.signed_out')
  end
end
