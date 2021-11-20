module Admin
  class BaseController < ApplicationController
    protect_from_forgery with: :exception

    http_basic_authenticate_with(
      name: ENV.fetch('ADMIN_BASIC_AUTH').split(':').first,
      password: ENV.fetch('ADMIN_BASIC_AUTH').split(':').last,
    )
  end
end
