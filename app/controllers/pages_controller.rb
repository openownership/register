# frozen_string_literal: true

class PagesController < ApplicationController
  BODS_EXPORT_REPOSITORY = Rails.application.config.bods_export_repository

  def download
    @exports = BODS_EXPORT_REPOSITORY.completed_exports(limit: 5)

    @example_entity = formatted_json(example_entity)
    @example_person = formatted_json(example_person)
    @example_ownership = formatted_json(example_ownership)

    @example_official_identifier = formatted_json(example_official_identifier)
    @example_oc_identifier = formatted_json(example_oc_identifier)
    @example_register_identifier = formatted_json(example_register_identifier)
    @example_unofficial_company_identifier = formatted_json(example_unofficial_company_identifier)
    @example_unofficial_person_identifier = formatted_json(example_unofficial_person_identifier)
    @example_composite_unofficial_person_identifier = formatted_json(example_composite_unofficial_person_identifier)
  end

  def download_latest
    exports = BODS_EXPORT_REPOSITORY.completed_exports(limit: 1)
    redirect_to "https://#{ENV.fetch('BODS_EXPORT_S3_BUCKET_NAME')}.s3-eu-west-1.amazonaws.com/#{exports.first.s3_path}"
  end

  def data_changelog
    @exports = BODS_EXPORT_REPOSITORY.completed_exports(limit: 5)
  end

  private

  def formatted_json(hash)
    # rubocop:disable Rails/OutputSafety
    CodeRay
      .scan(JSON.pretty_generate(hash), :json)
      .div(line_numbers: :table)
      .html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def example_entity
    {
      statementID: 'openownership-register-123456789',
      statementType: 'entityStatement',
      entityType: 'registeredEntity',
      name: 'EXAMPLE LTD',
      foundingDate: '2019-10-01',
      identifiers: [
        example_official_identifier,
        example_unofficial_company_identifier,
        example_register_identifier,
        example_oc_identifier
      ],
      incorporatedInJurisdiction: {
        code: 'GB',
        name: 'United Kingdom'
      },
      addresses: [
        {
          type: 'registered',
          address: 'Example street, London, SW1A 1AA',
          country: 'GB'
        }
      ]
    }
  end

  def example_person
    {
      statementID: '0openownership-register-91011121314',
      statementType: 'personStatement',
      statementDate: '2019-10-01',
      personType: 'knownPerson',
      identifiers: [
        example_unofficial_person_identifier,
        {
          schemeName: 'OpenOwnership Register',
          id: 'https://register.openownership.org/entities/abcdefg678910',
          uri: 'https://register.openownership.org/entities/abcdefg678910'
        }
      ],
      nationalities: [
        {
          code: 'GB',
          name: 'United Kingdom'
        }
      ],
      names: [
        {
          type: 'individual',
          fullName: 'Jane Smith'
        }
      ],
      birthDate: '1973-01',
      addresses: [
        {
          address: 'Example street, London, SW1A 1AA',
          country: 'GB'
        }
      ]
    }
  end

  def example_ownership
    {
      statementID: 'openownership-register-1516171819',
      statementType: 'ownershipOrControlStatement',
      statementDate: '2019-10-01',
      subject: {
        describedByEntityStatement: 'openownership-register-123456789'
      },
      interestedParty: {
        describedByPersonStatement: 'openownership-register-91011121314'
      },
      interests: [
        {
          type: 'shareholding',
          startDate: '2019-10-01',
          share: {
            exact: 100
          }
        }
      ]
    }
  end

  def example_official_identifier
    {
      scheme: 'GB-COH',
      schemeName: 'Companies House',
      id: '0123456'
    }
  end

  def example_unofficial_company_identifier
    {
      schemeName: 'GB Persons Of Significant Control Register',
      id: '0123456'
    }
  end

  def example_unofficial_person_identifier
    {
      schemeName: 'GB Persons Of Significant Control Register',
      id: '/company/0123456/persons-with-significant-control/individual/hijklmn12343'
    }
  end

  def example_composite_unofficial_person_identifier
    {
      schemeName: 'UA Edinyy Derzhavnyj Reestr',
      id: '12345-Test Person'
    }
  end

  def example_register_identifier
    {
      schemeName: 'OpenOwnership Register',
      id: 'https://register.openownership.org/entities/abcdefg12345',
      uri: 'https://register.openownership.org/entities/abcdefg12345'
    }
  end

  def example_oc_identifier
    {
      schemeName: 'OpenCorporates',
      id: 'https://opencorporates.com/companies/gb/0123456',
      uri: 'https://opencorporates.com/companies/gb/0123456'
    }
  end
end
