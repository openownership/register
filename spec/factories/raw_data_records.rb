FactoryGirl.define do
  factory :raw_data_record do
    sequence(:data) { |n| { "test" => n } }

    after(:build) do |record|
      record.etag = RawDataRecord.etag(record.data) if record.etag.blank?
    end
  end
end
