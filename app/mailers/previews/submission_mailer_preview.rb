class SubmissionMailerPreview < ActionMailer::Preview
  def submission_approved
    SubmissionMailer.submission_approved(Submissions::Submission.approved.first)
  end
end
