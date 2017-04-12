FactoryGirl.define do
  factory :provenance do
    source_url "http://www.example.com"
    source_name "Example Source"
    retrieved_at 2.weeks.ago
    imported_at 2.days.ago
  end
end
