FactoryGirl.define do
  factory :data_source_statistic do
    sequence(:type) { |n| "statistic-#{n}" }
    value 1

    factory :total_statistic do
      type DataSourceStatistic::Types::TOTAL
      value 100
    end
  end
end
