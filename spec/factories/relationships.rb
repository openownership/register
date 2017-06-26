FactoryGirl.define do
  factory :relationship do
    sequence(:id) { |n| { 'identifier' => n } }
    association :source, factory: :natural_person
    association :target, factory: :legal_entity
    sample_date '2017-01-23'
    provenance
  end
end
