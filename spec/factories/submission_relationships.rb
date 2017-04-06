FactoryGirl.define do
  factory :submission_relationship, class: Submissions::Relationship do
    association :source, factory: :submission_legal_entity
    association :target, factory: :submission_natural_person

    trait :interests do
      sequence(:ownership_of_shares_percentage) { |n| n % 4 == 0 ? 10.0 : nil }
      sequence(:voting_rights_percentage) { |n| n % 4 == 1 ? 10.0 : nil }
      sequence(:right_to_appoint_and_remove_directors) { |n| n % 4 == 2 }
      sequence(:other_significant_influence_or_control) { |n| n % 4 == 3 ? 'Hello world' : nil }
    end
  end
end
