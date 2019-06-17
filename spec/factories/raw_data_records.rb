FactoryGirl.define do
  factory :raw_data_record do
    sequence(:data) { |n| { "test" => n } }

    after(:build) do |record|
      record.etag = XXhash.xxh64(record.data).to_s if record.etag.blank?
    end
  end
end
