FactoryGirl.define do
  factory :user do
    sequence(:name) { |n| "Example User #{n}" }
    sequence(:email) { |n| "user-#{n}@example.com" }
    password "hunter2"
    password_confirmation "hunter2"
    confirmed_at 10.minutes.ago
    company_name 'Example Ltd'
    position 'Engineer'
  end
end
