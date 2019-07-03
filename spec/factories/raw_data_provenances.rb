FactoryGirl.define do
  factory :raw_data_provenance do
    association :entity_or_relationship, factory: :legal_entity
    association :import
    raw_data_records { [FactoryGirl.create_list(:raw_data_record, 2)] }
  end
end
