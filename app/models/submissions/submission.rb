module Submissions
  class Submission
    include Mongoid::Document
    include Timestamps::UpdatedEvenOnUpsert

    scope :started, -> { where(:entities_count.gt => 0) }
    scope :draft, -> { started.where(submitted_at: nil) }
    scope :submitted, -> { started.where(:submitted_at.ne => nil) }
    scope :reviewable, -> { submitted.where(approved_at: nil) }
    scope :approved, -> { where(:approved_at.ne => nil) }

    belongs_to :user, class_name: "User", inverse_of: :submissions

    has_many :entities, class_name: 'Submissions::Entity', dependent: :destroy, inverse_of: :submission
    field :entities_count, type: Integer, default: 0
    has_many :relationships, class_name: 'Submissions::Relationship', dependent: :destroy, inverse_of: :submission

    field :submitted_at, type: Time
    field :approved_at, type: Time
    field :changed_at, type: Time

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

    def approved?
      approved_at.present?
    end

    def reviewable?
      submitted? && !approved?
    end

    def changed!
      update_attribute(:changed_at, Time.zone.now)
    end

    def created_at
      id.generation_time
    end
  end
end
