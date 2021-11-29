FactoryBot.define do
  factory :data_source do
    url { "http://www.example.com" }
    sequence(:name) { |n| "Example Source #{n}" }
    sequence(:document_id) { |n| "Source #{n}" }
    types { ['officialRegister'] }

    factory :psc_data_source do
      url { 'http://download.companieshouse.gov.uk/en_pscdata.html' }
      name { 'UK PSC Register' }
      document_id { 'GB PSC Snapshot' }
    end

    factory :sk_data_source do
      url { 'https://rpvs.gov.sk/' }
      name { 'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)' }
      document_id { 'Slovakia PSP Register' }
    end

    factory :dk_data_source do
      url { 'https://cvr.dk' }
      name { 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])' }
      document_id { 'Denmark CVR' }
    end

    factory :ua_data_source do
      name { 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])' }
      url { 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10' }
      document_id { 'Ukraine EDR' }
    end

    factory :eiti_data_source do
      name { 'EITI Pilot Data - Example' }
      url { 'https://docs.google.com/spreadsheets/d/1OKl6oe6RbYicPIZEGljYZy29M06Pm4vGvGDoNzq6dV4' }
      document_id { 'EITI Structured Data - Example' }
      types { %w[thirdParty primaryResearch] }
    end

    factory :oor_data_source do
      name { 'OpenOwnership Register' }
      url { 'https://register.openownership.org' }
      document_id { nil }
      types { %w[thirdParty selfDeclaration] }
    end
  end
end
