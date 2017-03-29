module Submissions
  class Submission
    include Mongoid::Document

    scope :started, -> { where(:entities_count.gt => 0) }
    scope :draft, -> { started.where(submitted_at: nil) }
    scope :submitted, -> { started.where(:submitted_at.ne => nil) }

    belongs_to :user

    has_many :entities, class_name: 'Submissions::Entity'
    has_many :relationships, class_name: 'Submissions::Relationship'

    field :submitted_at, type: Time

    def entity
      entities.legal_entities.first
    end

    def draft?
      submitted_at.nil?
    end

    def submitted?
      submitted_at.present?
    end

    def started?
      entity.present?
    end
  end
end
