FactoryGirl.define do
  factory :raw_data_provenance do
    association :entity_or_relationship, factory: :legal_entity
    association :import
    raw_data_records { [FactoryGirl.build_list(:raw_data_record, 2)] }

    after(:build) do |provenance|
      provenance.raw_data_records.each do |r|
        r.imports << provenance.import
        r.save!
      end
    end
  end
end
