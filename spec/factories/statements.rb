FactoryGirl.define do
  factory :statement do
    type 'no-individual-or-entity-with-signficant-control'
    date '2017-01-23'
    association :entity, factory: :legal_entity
  end
end
