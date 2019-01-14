module UserHelpers
  def signin_as(user)
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Sign in'
  end

  def signin_success_message
    I18n.t('devise.sessions.signed_in')
  end
end
