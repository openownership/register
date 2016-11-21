Rails.application.config.action_controller.per_form_csrf_tokens = true
Rails.application.config.action_controller.forgery_protection_origin_check = true
ActiveSupport.to_time_preserves_timezone = true
ActiveSupport.halt_callback_chains_on_return_false = false
Rails.application.config.ssl_options = { hsts: { subdomains: true } }
