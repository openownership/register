FactoryBot.define do
  factory :submission_entity, class: Submissions::Entity do
    submission

    factory :submission_legal_entity do
      type { Entity::Types::LEGAL_ENTITY }
      sequence(:name) { |n| "Example Company #{n}" }
      jurisdiction_code { "gb" }
      incorporation_date { 10.years.ago }
      company_number { "12345678" }
    end

    factory :submission_natural_person do
      type { Entity::Types::NATURAL_PERSON }
      sequence(:name) { |n| "Example Person #{n}" }
      dob { 50.years.ago.to_date.to_s }
      country_of_residence { "gb" }
      nationality { "gb" }
      address { "61 Example Road, N1 1XY" }
    end
  end
end
