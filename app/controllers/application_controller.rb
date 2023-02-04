class ApplicationController < ActionController::Base
  include BooleanParam
  include DecorateHelpers

  helper_method :decorate

  protect_from_forgery with: :exception

  before_action :parse_should_transliterate_param

  protected

  attr_reader :should_transliterate

  def parse_should_transliterate_param
    @should_transliterate = boolean_param(:transliterated)
  end
end
