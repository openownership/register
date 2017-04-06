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
        create(:submission_relationship, :interests, submission: submission, source: source, target: target)
      end
    end

    factory :approved_submission, parent: :submitted_submission do
      approved_at 2.minutes.ago

      after(:create) do |submission|
        entities = {}

        provenance = build(
          :provenance,
          source_url: "https://register.openownership.org",
          source_name: "OpenOwnership Register",
          retrieved_at: submission.submitted_at,
          imported_at: Time.now.utc,
        )

        submission.entities.each do |entity|
          entities[entity.id] = create(:entity, entity.attributes_for_submission.merge(identifiers: [{ _id: entity.id }]))
        end

        submission.relationships.each do |relationship|
          create(
            :relationship,
            _id: relationship.id,
            source: entities[relationship.source_id],
            target: entities[relationship.target_id],
            interests: relationship.interests,
            sample_date: submission.submitted_at.to_date.to_s,
            provenance: provenance,
          )
        end
      end
    end
  end
end
