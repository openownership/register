module Submissions
  class RelationshipsController < ApplicationController
    before_action :authenticate_user!
    before_action :find_submission

    def edit
      @relationship = @submission.relationships.find(params[:id])
    end

    def update
      @relationship = @submission.relationships.find(params[:id])

      if @relationship.update_attributes(relationship_params)
        @submission.changed!
        redirect_to edit_submission_path(@submission)
      else
        render :edit
      end
    end

    private

    def relationship_params
      params.require(:relationship).permit(
        :ownership_of_shares_percentage,
        :voting_rights_percentage,
        :right_to_appoint_and_remove_directors,
        :other_significant_influence_or_control,
      )
    end

    def find_submission
      @submission = current_user.submissions.find(params[:submission_id])
    end
  end
end
