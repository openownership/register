module SubmissionHelpers
  def stub_opencorporates_api_for_search
    instance = instance_double("OpencorporatesClient")
    allow(OpencorporatesClient).to receive(:new).and_return(instance)
    allow(instance).to receive(:search_companies_by_name).and_return(
      [
        {
          company: {
            name: "Acme Corporation",
            company_number: "12345678",
            jurisdiction_code: "gb",
            incorporation_date: "1987-09-27",
            dissolution_date: nil,
            company_type: "Private Limited Company",
            registry_url: "https://beta.companieshouse.gov.uk/company/12345678",
            branch_status: nil,
            inactive: false,
            current_status: "Active",
            created_at: "2010-12-18T01:35:14+00:00",
            updated_at: "2017-03-13T00:54:31+00:00",
            retrieved_at: "2017-03-13T00:54:31+00:00",
            opencorporates_url: "https://opencorporates.com/companies/gb/12345678",
            previous_names: [],
            source: {
              publisher: "UK Companies House",
              url: "http://xmlgw.companieshouse.gov.uk/",
              terms: "UK Crown Copyright",
              retrieved_at: "2017-03-13T00:54:31+00:00"
            },
            registered_address: {
              street_address: "123 Example Road",
              locality: "London",
              region: nil,
              postal_code: "AB1 2XY",
              country: "United Kingdom"
            },
            registered_address_in_full: "123 Example Road, London, AB1 2XY",
            restricted_for_marketing: nil,
            native_company_number: nil
          }
        }
      ]
    )
  end
end
