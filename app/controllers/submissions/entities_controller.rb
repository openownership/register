module Submissions
  class EntitiesController < ApplicationController
    before_action :authenticate_user!
    before_action :find_submission
    before_action :find_target, if: -> { params[:target_id].present? }
    before_action :find_source, if: -> { params[:source_ids].try(:size) == 1 }
    helper_method :continue_params

    def choose
      find_companies_from_submission
      find_people_from_submission
    end

    def search
      find_companies_from_submission
      find_companies_from_opencorporates if params[:q].present?
    end

    def new
      @entity = @submission.entities.new(entity_params.merge(user_created: true))
    end

    def use
      @entity = @submission.entities.find(params[:id])

      split_relationships if params[:source_ids].present? && params[:target_id].present?
      create_relationship_as_source if params[:source_ids].blank? && params[:target_id].present?

      @submission.changed!

      redirect_to edit_submission_path(@submission)
    end

    def create
      @entity = @submission.entities.new

      validate_dob

      @entity.assign_attributes(entity_params)

      if @entity.save
        @submission.changed!
        split_relationships if params[:source_ids].present? && params[:target_id].present?
        create_relationship_as_source if params[:source_ids].blank? && params[:target_id].present?
        redirect_to edit_submission_path(@submission)
      else
        render :new
      end
    end

    def edit
      @entity = @submission.entities.find(params[:id])
    end

    def update
      @entity = @submission.entities.find(params[:id])

      validate_dob

      if @entity.update_attributes(entity_params)
        @submission.changed!
        redirect_to edit_submission_path(@submission)
      else
        render :edit
      end
    end

    def destroy
      entity = @submission.entities.find(params[:id])
      relationship = @submission.relationships.find(params[:relationship_id])

      entity.relationships_as_target.each do |relationship_as_target|
        @submission.relationships.find_or_create_by!(
          source: relationship_as_target.source,
          target: relationship.target,
        )
        relationship_as_target.destroy!
      end

      relationship.destroy!

      @submission.changed!

      redirect_to edit_submission_path(@submission)
    end

    private

    def validate_dob
      date = ISO8601::Date.new(entity_params[:dob])
      entity_params[:dob] = nil if date.atoms.length < 3
    rescue ISO8601::Errors::UnknownPattern
      entity_params[:dob] = nil
    end

    def find_target
      @target = @submission.entities.find(params[:target_id])
    end

    def find_source
      @source = @submission.entities.find(params[:source_ids].first)
    end

    def find_companies_from_opencorporates
      @companies_from_opencorporates = opencorporates_client
        .search_companies_by_name(params[:q])
        .map(&method(:legal_entity_from))

      return unless @companies_from_opencorporates.nil?

      @companies_from_opencorporates = []
      flash.now[:alert] = I18n.t('submissions.entities.search.timeout')
    end

    def opencorporates_client
      OpencorporatesClient.new.tap do |client|
        client.http.read_timeout = 10.0
      end
    end

    def find_companies_from_submission
      @companies_from_submission = @submission.entities.legal_entities
    end

    def find_people_from_submission
      @people_from_submission = @submission.entities.natural_persons
    end

    def split_relationships
      params[:source_ids].each do |source_id|
        relationship = @submission.relationships.find_by!(
          source_id: source_id,
          target_id: params[:target_id],
        )

        @submission.relationships.find_or_create_by!(
          source: relationship.source,
          target: @entity,
        )

        @submission.relationships.find_or_create_by!(
          source: @entity,
          target: relationship.target,
        )

        relationship.destroy!
      end
    end

    def legal_entity_from(result)
      attributes = result[:company]
        .slice(*Submissions::Entity::ATTRIBUTES_FOR_SUBMISSION)
        .merge(
          type: Entity::Types::LEGAL_ENTITY,
          address: result[:company][:registered_address_in_full],
        )

      Submissions::Entity.new(attributes)
    end

    def create_relationship_as_source
      @submission.relationships.find_or_create_by!(
        source: @entity,
        target_id: params[:target_id],
      )
    end

    def continue_params
      params.permit(
        :target_id,
        source_ids: [],
      )
    end

    def entity_params
      @entity_params ||= params.require(:entity).permit(
        *Submissions::Entity::ATTRIBUTES_FOR_SUBMISSION,
        :user_created,
      )
    end

    def find_submission
      @submission = current_user.submissions.find(params[:submission_id])
    end
  end
end
