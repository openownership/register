class SubmissionMailer < ApplicationMailer
  default from: if ENV.key?('HEROKU_APP_NAME')
                  format 'OpenOwnership Register (%{app_name}) <register+%{app_name}@openownership.org>', app_name: ENV['HEROKU_APP_NAME']
                else
                  'OpenOwnership Register <register@openownership.org>'
                end

  def submission_approved(submission)
    @submission = submission
    @entity = Entity.find_by(
      identifiers: {
        'submission_id' => @submission.id,
        'entity_id' => @submission.entity.id,
      },
    )
    mail(to: @submission.user.email, subject: I18n.t('submission_mailer.submission_approved.subject'))
  end
end
