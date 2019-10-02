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
      "statementID": "1dc0e987-5c57-4a1c-b3ad-61353b66a9b7",
      "statementType": "entityStatement",
      "entityType": "registeredEntity",
      "name": "EXAMPLE LTD",
      "foundingDate": "2019-10-01",
      "identifiers": [
        {
          "scheme": "GB-COH",
          "id": "0123456",
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
      "statementID": "019a93f1-e470-42e9-957b-03559861b2e2",
      "statementType": "personStatement",
      "statementDate": "2019-10-01",
      "personType": "knownPerson",
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
      "statementID": "fbfd0547-d0c6-4a00-b559-5c5e91c34f5c",
      "statementType": "ownershipOrControlStatement",
      "statementDate": "2019-10-01",
      "subject": {
        "describedByEntityStatement": "1dc0e987-5c57-4a1c-b3ad-61353b66a9b7",
      },
      "interestedParty": {
        "describedByPersonStatement": "019a93f1-e470-42e9-957b-03559861b2e2",
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
