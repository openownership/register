module SubmissionHelper
  def submissions_section?
    controller.class.module_parent == Submissions
  end

  def link_to_edit_submission_entity(entity, options = {}, &block)
    if entity.persisted? && entity.try(:user_created?) && entity.submission.draft?
      link_to capture(&block), edit_submission_entity_path(entity.submission, entity), options
    else
      content_tag :span, capture(&block), options
    end
  end
end
