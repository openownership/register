FactoryGirl.define do
  factory :raw_data_record do
    sequence(:raw_data) { |n| { "test" => n }.to_json }

    after(:build) do |record|
      record.etag = RawDataRecord.etag(record.raw_data) if record.etag.blank?
    end
  end
end
