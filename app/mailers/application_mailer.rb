# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  layout 'mailer'

  def admin_emails
    ENV['ADMIN_EMAILS'] || 'tech@openownership.org'
  end
end
