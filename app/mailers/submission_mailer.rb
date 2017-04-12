class SubmissionMailer < ApplicationMailer
  default from: if ENV.key?('HEROKU_APP_NAME')
                  format 'OpenOwnership Register (%{app_name}) <system+%{app_name}@openownership.org>', app_name: ENV['HEROKU_APP_NAME']
                else
                  'OpenOwnership Register <system@openownership.org>'
                end

  def submission_approved(submission)
    @submission = submission
    @entity = Entity.find_by(identifiers: { _id: @submission.entity.id })
    mail(to: @submission.user.email, subject: I18n.t('submission_mailer.submission_approved.subject'))
  end
end
