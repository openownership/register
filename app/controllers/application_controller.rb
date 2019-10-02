class ApplicationController < ActionController::Base
  include BooleanParam
  include DecorateHelpers

  helper_method :decorate

  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :parse_should_transliterate_param

  before_action :set_seen_data_download_message

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name company_name position])
  end

  attr_reader :should_transliterate

  def parse_should_transliterate_param
    @should_transliterate = boolean_param(:transliterated)
  end

  def set_seen_data_download_message
    @seen_data_download_message = cookies.key? :seenDataDownloadAvailableMessage
  end
end
