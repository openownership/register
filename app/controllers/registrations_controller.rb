class RegistrationsController < Devise::RegistrationsController
  # Using before_action not prepend_before_action as documented because we want
  # the extra permitted parameters defined in ApplicationController to run first
  before_action :check_captcha, only: [:create] # rubocop:disable Rails/LexicallyScopedActionFilter

  private

  def check_captcha
    return if ENV['RECAPTCHA_SITE_KEY'].blank?
    return if verify_recaptcha

    self.resource = resource_class.new sign_up_params
    resource.validate # Look for any other validation errors besides Recaptcha
    resource.errors.add :captcha, I18n.t('devise.registrations.new.errors.captcha')
    set_minimum_password_length
    respond_with_navigational(resource) { render :new }
  end
end
