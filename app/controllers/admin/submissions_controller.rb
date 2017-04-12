module Admin
  class SubmissionsController < BaseController
    layout 'application'

    def index
      @submissions = Submissions::Submission.started
    end

    def show
      @submission = Submissions::Submission.find(params[:id])
      @node = TreeNode.new(@submission.entity)
      @entities = gather_entities
    end

    def approve
      submission = Submissions::Submission.find(params[:id])

      submission.update_attribute(:approved_at, Time.now.utc)

      SubmissionImporter.new(submission).import
      SubmissionMailer.submission_approved(submission).deliver_now

      redirect_to admin_submissions_path, notice: I18n.t('admin.submissions.approve.success', entity: submission.entity.name)
    end

    private

    def gather_entities
      entities = @submission.relationships.map do |relationship|
        [relationship.source, relationship.target]
      end

      entities.flatten.uniq
    end
  end
end
