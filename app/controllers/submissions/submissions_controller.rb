module Submissions
  class SubmissionsController < ApplicationController
    before_action :authenticate_user!

    def index
      @submissions = current_user.submissions.started
    end

    def create
      submission = current_user.submissions.create!
      redirect_to search_submission_entities_path(submission)
    end

    def submit
      submission = current_user.submissions.find(params[:id])
      submission.update_attribute(:submitted_at, Time.now.utc)
      SubmissionMailer.submission_approval_requested(submission).deliver_now
      redirect_to submissions_path, notice: I18n.t('submissions.submissions.submit.success', entity: submission.entity.name)
    end

    def edit
      @submission = current_user.submissions.find(params[:id])
      @node = TreeNode.new(@submission.entity)
      return redirect_to submission_path(@submission) if @submission.submitted?
      return redirect_to search_submission_entities_path(@submission) unless @submission.started?
    end

    def show
      @submission = current_user.submissions.find(params[:id])
      @node = TreeNode.new(@submission.entity)
      redirect_to edit_submission_path(@submission) if @submission.draft?
    end

    private

    def submission_step
      if @submission.relationships.empty?
        "just-started"
      elsif !all_relationships_ultimately_controlled?
        "add-controlling-entities"
      elsif !all_relationships_control_described?
        "describe-nature-of-control"
      else
        "ready-to-submit"
      end
    end
    helper_method :submission_step

    def all_relationships_ultimately_controlled?
      TreeNode
        .new(@submission.entity)
        .leaf_nodes
        .map(&:entity)
        .all?(&:natural_person?)
    end

    def all_relationships_control_described?
      @submission.relationships.all? { |r| r.interests.any? }
    end
  end
end
