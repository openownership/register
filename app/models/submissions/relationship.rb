module Submissions
  class Relationship
    include Mongoid::Document
    include Timestamps::UpdatedEvenOnUpsert

    belongs_to :submission
    belongs_to :source, class_name: 'Submissions::Entity', inverse_of: :relationships_as_source
    belongs_to :target, class_name: 'Submissions::Entity', inverse_of: :relationships_as_target

    field :started_date, type: ISO8601::Date
    field :ended_date, type: ISO8601::Date
    field :is_indirect, type: TrueClass

    field :ownership_of_shares_percentage, type: Float
    field :voting_rights_percentage, type: Float
    field :right_to_appoint_and_remove_directors, type: TrueClass, default: false
    field :other_significant_influence_or_control, type: String

    validates :ownership_of_shares_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, if: -> { ownership_of_shares_percentage.present? }
    validates :voting_rights_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, if: -> { voting_rights_percentage.present? }
    validate :at_least_one_interest, on: :update

    def interests
      arr = []
      arr << I18n.t('submissions.relationships.interests.ownership_of_shares_percentage', value: ownership_of_shares_percentage) if ownership_of_shares_percentage.try(:nonzero?)
      arr << I18n.t('submissions.relationships.interests.voting_rights_percentage', value: voting_rights_percentage) if voting_rights_percentage.try(:nonzero?)
      arr << I18n.t('submissions.relationships.interests.right_to_appoint_and_remove_directors') if right_to_appoint_and_remove_directors?
      arr << I18n.t('submissions.relationships.interests.other_significant_influence_or_control', value: other_significant_influence_or_control) if other_significant_influence_or_control.present?
      arr
    end

    private

    def at_least_one_interest
      errors.add(:base, I18n.t('submissions.relationships.errors.blank_interests')) unless interests.any?
    end
  end
end
