FactoryGirl.define do
  factory :submission_relationship, class: Submissions::Relationship do
    association :source, factory: :submission_legal_entity
    association :target, factory: :submission_natural_person
  end
end
