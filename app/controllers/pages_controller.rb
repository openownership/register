class PagesController < ApplicationController
  def download
    @exports = BodsExport.where(:completed_at.ne => nil).desc(:created_at).take(5)
    # rubocop:disable Rails/OutputSafety
    @example_entity = CodeRay.scan(JSON.pretty_generate(example_entity), :json).div(line_numbers: :table).html_safe
    @example_person = CodeRay.scan(JSON.pretty_generate(example_person), :json).div(line_numbers: :table).html_safe
    @example_ownership = CodeRay.scan(JSON.pretty_generate(example_ownership), :json).div(line_numbers: :table).html_safe
    # rubocop:enable Rails/OutputSafety
  end

  private

  def example_entity
    {
      "statementID": "openownership-register-123456789",
      "statementType": "entityStatement",
      "entityType": "registeredEntity",
      "name": "EXAMPLE LTD",
      "foundingDate": "2019-10-01",
      "identifiers": [
        {
          "scheme": "GB-COH",
          "schemeName": "Companies House",
          "id": "0123456",
        },
        {
          "schemeName": "GB Persons Of Significant Control Register",
          "id": "0123456",
        },
        {
          "schemeName": "OpenOwnership Register",
          "id": "https://register.openownership.org/entities/abcdefg12345",
          "uri": "https://register.openownership.org/entities/abcdefg12345",
        },
        {
          "schemeName": "OpenCorporates",
          "id": "https://opencorporates.com/companies/gb/0123456",
          "uri": "https://opencorporates.com/companies/gb/0123456",
        },
      ],
      "incorporatedInJurisdiction": {
        "code": "GB",
        "name": "United Kingdom",
      },
      "addresses": [
        {
          "type": "registered",
          "address": "Example street, London, SW1A 1AA",
          "country": "GB",
        },
      ],
    }
  end

  def example_person
    {
      "statementID": "0openownership-register-91011121314",
      "statementType": "personStatement",
      "statementDate": "2019-10-01",
      "personType": "knownPerson",
      "identifiers": [
        {
          "schemeName": "GB Persons Of Significant Control Register",
          "id": "/company/0123456/persons-with-significant-control/individual/hijklmn12343",
        },
        {
          "schemeName": "OpenOwnership Register",
          "id": "https://register.openownership.org/entities/abcdefg678910",
          "uri": "https://register.openownership.org/entities/abcdefg678910",
        },
      ],
      "nationalities": [
        {
          "code": "GB",
          "name": "United Kingdom",
        },
      ],
      "names": [
        {
          "type": "individual",
          "fullName": "Jane Smith",
        },
      ],
      "birthDate": "1973-01",
      "addresses": [
        {
          "address": "Example street, London, SW1A 1AA",
          "country": "GB",
        },
      ],
    }
  end

  def example_ownership
    {
      "statementID": "openownership-register-1516171819",
      "statementType": "ownershipOrControlStatement",
      "statementDate": "2019-10-01",
      "subject": {
        "describedByEntityStatement": "openownership-register-123456789",
      },
      "interestedParty": {
        "describedByPersonStatement": "openownership-register-91011121314",
      },
      "interests": [
        {
          "type": "shareholding",
          "startDate": "2019-10-01",
          "share": {
            "exact": 100,
          },
        },
      ],
    }
  end
end
