FactoryGirl.define do
  factory :data_source_statistic do
    sequence(:type) { |n| "statistic-#{n}" }
    value 1
  end
end
