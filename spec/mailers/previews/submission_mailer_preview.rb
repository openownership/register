class SubmissionMailerPreview < ActionMailer::Preview
  def submission_approved
    SubmissionMailer.submission_approved(Submissions::Submission.approved.first)
  end

  def submission_approval_requested
    SubmissionMailer.submission_approval_requested(Submissions::Submission.reviewable.first)
  end
end
