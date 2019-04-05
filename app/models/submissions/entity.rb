module Submissions
  class Entity
    include ActsAsEntity

    ATTRIBUTES_FOR_SUBMISSION = %i[
      type
      name
      address
      nationality
      country_of_residence
      dob
      jurisdiction_code
      company_number
      incorporation_date
      dissolution_date
      company_type
    ].freeze

    belongs_to :submission, inverse_of: :entities, counter_cache: :entities_count
    has_many :relationships_as_source, class_name: "Submissions::Relationship", inverse_of: :source
    has_many :relationships_as_target, class_name: "Submissions::Relationship", inverse_of: :target

    field :user_created, type: Boolean, default: false

    validates :name, presence: true
    validates :jurisdiction_code, presence: true, if: :legal_entity?
    validates :incorporation_date, presence: true, if: ->(record) { record.user_created? && record.legal_entity? }
    validate :incorporation_date_is_in_past, if: ->(record) { record.user_created? && record.legal_entity? }
    validates :company_number, presence: true, if: :legal_entity?
    validates :dob, presence: { message: I18n.t('submissions.entities.errors.must_be_present_and_valid_date_format') }, if: :natural_person?
    validate :dob_is_in_past, if: :natural_person?
    validates :country_of_residence, presence: true, if: :natural_person?
    validates :nationality, presence: true, if: :natural_person?
    validates :address, presence: true, if: :natural_person?

    def attributes_for_submission
      attributes.with_indifferent_access.slice(*ATTRIBUTES_FOR_SUBMISSION)
    end

    private

    def incorporation_date_is_in_past
      errors.add(:incorporation_date, I18n.t('submissions.entities.errors.must_be_in_past')) if incorporation_date.try(:future?)
    end

    def dob_is_in_past
      errors.add(:dob, I18n.t('submissions.entities.errors.must_be_in_past')) if dob.try(:to_date).try(:future?)
    end
  end
end
