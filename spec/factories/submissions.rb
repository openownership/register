FactoryGirl.define do
  factory :submission, class: Submissions::Submission do
    user

    factory :draft_submission do
      after(:create) do |submission|
        create(:submission_legal_entity, submission: submission)
      end
    end

    factory :submitted_submission do
      submitted_at 5.minutes.ago
      after(:create) do |submission|
        target = create(:submission_legal_entity, submission: submission)
        source = create(:submission_natural_person, submission: submission)
        create(:submission_relationship, submission: submission, source: source, target: target)
      end
    end
  end
end
