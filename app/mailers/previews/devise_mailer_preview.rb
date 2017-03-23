module Devise
  class MailerPreview < ActionMailer::Preview
    def confirmation_instructions
      Mailer.confirmation_instructions(User.first, "abc123")
    end

    def reset_password_instructions
      Mailer.reset_password_instructions(User.first, "abc123")
    end
  end
end
