require 'rails_helper'

RSpec.shared_context 'BODS: basic entity with one owner' do
  include_context 'basic entity with one owner'
  let(:person_id) { BodsMapper.new.statement_id(person) }
  let(:company_id) { BodsMapper.new.statement_id(company) }
  let(:relationship_id) { BodsMapper.new.statement_id(relationship) }

  let(:expected_statements) do
    [
      {
        'statementID' => company_id,
        'statementType' => 'entityStatement',
        'entityType' => 'registeredEntity',
        'name' => company.name,
        'identifiers' => [],
        'foundingDate' => 10.years.ago.to_date.iso8601,
        'incorporatedInJurisdiction' => {
          'name' => 'United Kingdom of Great Britain and Northern Ireland',
          'code' => 'GB',
        },
      },
      {
        'statementID' => person_id,
        'statementType' => 'personStatement',
        'personType' => 'knownPerson',
        'names' => [
          'type' => 'individual',
          'fullName' => person.name,
        ],
        'identifiers' => [],
        'nationalities' => [
          {
            'name' => 'United Kingdom of Great Britain and Northern Ireland',
            'code' => 'GB',
          },
        ],
        'birthDate' => 50.years.ago.to_date.iso8601,
        'addresses' => [
          {
            'address' => '61 Example Road, N1 1XY',
            'country' => 'GB',
          },
        ],
      },
      {
        'statementID' => relationship_id,
        'statementType' => 'ownershipOrControlStatement',
        'statementDate' => '2017-01-23',
        'subject' => {
          'describedByEntityStatement' => company_id,
        },
        'interestedParty' => {
          'describedByPersonStatement' => person_id,
        },
        'interests' => [
          {
            'type' => 'shareholding',
            'details' => 'ownership-of-shares-75-to-100-percent',
            'share' => {
              'minimum' => 75,
              'maximum' => 100,
              'exclusiveMinimum' => false,
              'exclusiveMaximum' => false,
            },
          },
        ],
      },
    ]
  end
end

RSpec.shared_context 'BODS: company that is part of a chain of relationships' do
  let!(:legal_entity_1) do
    create(
      :legal_entity,
      identifiers: [
        { jurisdiction_code: 'gb', company_number: '12345' },
        { document_id: 'GB PSC Snapshot', company_number: '12345' },
      ],
      name: 'Company A',
      address: '123 not hidden street',
      jurisdiction_code: 'gb',
      company_number: '12345',
      incorporation_date: 2.months.ago,
      dissolution_date: 1.month.ago,
    )
  end

  let!(:legal_entity_2) do
    create(
      :legal_entity,
      identifiers: [
        { jurisdiction_code: 'dk', company_number: '67890' },
        { document_id: 'Denmark CVR', company_number: '67890' },
        { document_id: 'GB PSC Snapshot', link: 'fooo', company_number: '67890' },
      ],
      name: 'Company B',
      address: '1234 hidden street',
      jurisdiction_code: 'dk',
      company_number: '67890',
      incorporation_date: 2.months.ago,
      dissolution_date: 1.month.ago,
    )
  end

  let!(:natural_person) do
    create(
      :natural_person,
      identifiers: [
        { document_id: 'Denmark CVR', beneficial_owner_id: 'P123456' },
      ],
      name: 'Miss Yander Stud',
      address: '25 road street',
      dob: 50.years.ago.to_date.to_s,
      country_of_residence: 'gb',
      nationality: 'gb',
    )
  end

  let(:retrieved_at) { 2.weeks.ago }

  let!(:relationships) do
    [
      create(
        :relationship,
        source: legal_entity_2,
        target: legal_entity_1,
        interests: [
          'ownership-of-shares-25-to-50-percent',
          'voting-rights-50-to-75-percent',
          'significant-influence-or-control',
          'blah nlah nlah',
        ],
        provenance: attributes_for(
          :provenance,
          source_name: 'UK PSC Register',
          retrieved_at: retrieved_at,
        ),
      ),
      create(
        :relationship,
        source: natural_person,
        target: legal_entity_2,
        interests: [
          {
            type: 'shareholding',
            share_min: 100,
            share_max: 100,
          },
          {
            type: 'voting-rights',
            share_min: 25,
            share_max: 49.99,
          },
          'significant-influence-or-control',
        ],
        provenance: attributes_for(
          :provenance,
          source_name: 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])',
          retrieved_at: retrieved_at,
        ),
      ),
    ]
  end

  let(:legal_entity_1_id) { BodsMapper.new.statement_id(legal_entity_1) }
  let(:legal_entity_2_id) { BodsMapper.new.statement_id(legal_entity_2) }
  let(:natural_person_id) { BodsMapper.new.statement_id(natural_person) }
  let(:legal_entity_1_legal_entity_2_relationship_id) do
    BodsMapper.new.statement_id(relationships.first)
  end
  let(:legal_entity_2_natural_person_relationship_id) do
    BodsMapper.new.statement_id(relationships.second)
  end

  let(:expected_statements) do
    [
      {
        'statementID' => legal_entity_2_id,
        'statementType' => 'entityStatement',
        'entityType' => 'registeredEntity',
        'name' => legal_entity_2.name,
        'identifiers' => [
          {
            'scheme' => 'DK-CVR',
            'id' => '67890',
          },
        ],
        'foundingDate' => 2.months.ago.to_date.iso8601,
        'dissolutionDate' => 1.month.ago.to_date.iso8601,
        'addresses' => [
          {
            'type' => 'registered',
            'address' => '1234 hidden street',
            'country' => 'DK',
          },
        ],
        'incorporatedInJurisdiction' => {
          'name' => 'Denmark',
          'code' => 'DK',
        },
      },
      {
        'statementID' => natural_person_id,
        'statementType' => 'personStatement',
        'personType' => 'knownPerson',
        'names' => [
          'type' => 'individual',
          'fullName' => natural_person.name,
        ],
        'identifiers' => [
          {
            'scheme' => 'MISC-Denmark CVR',
            'id' => 'P123456',
          },
        ],
        'nationalities' => [
          {
            'name' => 'United Kingdom of Great Britain and Northern Ireland',
            'code' => 'GB',
          },
        ],
        'birthDate' => 50.years.ago.to_date.iso8601,
        'addresses' => [
          {
            'address' => '25 road street',
            'country' => 'GB',
          },
        ],
      },
      {
        'statementID' => legal_entity_2_natural_person_relationship_id,
        'statementType' => 'ownershipOrControlStatement',
        'statementDate' => '2017-01-23',
        'subject' => {
          'describedByEntityStatement' => legal_entity_2_id,
        },
        'interestedParty' => {
          'describedByPersonStatement' => natural_person_id,
        },
        'interests' => [
          {
            'type' => 'shareholding',
            'share' => {
              'exact' => 100,
              'minimum' => 100,
              'maximum' => 100,
            },
          },
          {
            'type' => 'voting-rights',
            'share' => {
              'minimum' => 25,
              'maximum' => 49.99,
              'exclusiveMinimum' => false,
              'exclusiveMaximum' => false,
            },
          },
          {
            'type' => 'influence-or-control',
            'details' => 'significant-influence-or-control',
          },
        ],
        'source' => {
          'type' => ['officialRegister'],
          'description' => 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])',
          'url' => 'http://www.example.com',
          'retrievedAt' => retrieved_at.iso8601,
        },
      },
      {
        'statementID' => legal_entity_1_id,
        'statementType' => 'entityStatement',
        'entityType' => 'registeredEntity',
        'name' => legal_entity_1.name,
        'identifiers' => [
          {
            'scheme' => 'GB-COH',
            'id' => '12345',
          },
        ],
        'foundingDate' => 2.months.ago.to_date.iso8601,
        'dissolutionDate' => 1.month.ago.to_date.iso8601,
        'addresses' => [
          {
            'type' => 'registered',
            'address' => '123 not hidden street',
            'country' => 'GB',
          },
        ],
        'incorporatedInJurisdiction' => {
          'name' => 'United Kingdom of Great Britain and Northern Ireland',
          'code' => 'GB',
        },
      },
      {
        'statementID' => legal_entity_1_legal_entity_2_relationship_id,
        'statementType' => 'ownershipOrControlStatement',
        'statementDate' => '2017-01-23',
        'subject' => {
          'describedByEntityStatement' => legal_entity_1_id,
        },
        'interestedParty' => {
          'describedByEntityStatement' => legal_entity_2_id,
        },
        'interests' => [
          {
            'type' => 'shareholding',
            'details' => 'ownership-of-shares-25-to-50-percent',
            'share' => {
              'minimum' => 25,
              'maximum' => 50,
              'exclusiveMinimum' => true,
              'exclusiveMaximum' => false,
            },
          },
          {
            'type' => 'voting-rights',
            'details' => 'voting-rights-50-to-75-percent',
            'share' => {
              'minimum' => 50,
              'maximum' => 75,
              'exclusiveMinimum' => true,
              'exclusiveMaximum' => true,
            },
          },
          {
            'type' => 'influence-or-control',
            'details' => 'significant-influence-or-control',
          },
          {
            'type' => 'influence-or-control',
            'details' => 'blah nlah nlah',
          },
        ],
        'source' => {
          'type' => ['officialRegister'],
          'description' => 'UK PSC Register',
          'url' => 'http://www.example.com',
          'retrievedAt' => retrieved_at.iso8601,
        },
      },
    ]
  end
end

RSpec.shared_context 'BODS: company with no relationships' do
  let(:company) { create :legal_entity }
  let(:relationship) { CreateRelationshipsForStatements.call(company).first }
  let(:unknown_person) { relationship.source }

  let(:company_id) { BodsMapper.new.statement_id(company) }
  let(:unknown_person_id) { BodsMapper.new.statement_id(unknown_person) }
  let(:relationship_id) { BodsMapper.new.statement_id(relationship) }

  let(:expected_statements) do
    [
      {
        "statementID" => company_id,
        "statementType" => "entityStatement",
        "entityType" => "registeredEntity",
        "foundingDate" => 10.years.ago.to_date.iso8601,
        "identifiers" => [],
        "name" => company.name,
        'incorporatedInJurisdiction' => {
          'name' => 'United Kingdom of Great Britain and Northern Ireland',
          'code' => 'GB',
        },
      },
      {
        "statementID" => relationship_id,
        "statementType" => "ownershipOrControlStatement",
        "subject" => {
          "describedByEntityStatement" => company_id,
        },
        "interestedParty" => {
          "unspecified" => {
            "reason" => "unknown",
            "description" => "unknown",
          },
        },
        "interests" => [],
      },
    ]
  end
end

RSpec.shared_context 'BODS: company that declares an unknown owner' do
  let(:statement) { create :statement, type: 'psc-exists-but-not-identified' }
  let(:company) { statement.entity }
  let(:relationship) { CreateRelationshipsForStatements.call(company).first }
  let(:unknown_person) { relationship.source }

  let(:company_id) { BodsMapper.new.statement_id(company) }
  let(:unknown_person_id) { BodsMapper.new.statement_id(unknown_person) }
  let(:relationship_id) { BodsMapper.new.statement_id(relationship) }

  let(:expected_statements) do
    [
      {
        "statementID" => company_id,
        "statementType" => "entityStatement",
        "entityType" => "registeredEntity",
        "foundingDate" => 10.years.ago.to_date.iso8601,
        "identifiers" => [],
        "name" => company.name,
        'incorporatedInJurisdiction' => {
          'name' => 'United Kingdom of Great Britain and Northern Ireland',
          'code' => 'GB',
        },
      },
      {
        "statementID" => unknown_person_id,
        "statementType" => "personStatement",
        "personType" => "unknownPerson",
        "missingInfoReason" => "The company knows or has reasonable cause to believe that there is a registrable person in relation to the company but it has not identified the registrable person",
        "addresses" => [],
        "identifiers" => [],
        "names" => [],
        "nationalities" => [],
      },
      {
        "statementID" => relationship_id,
        "statementType" => "ownershipOrControlStatement",
        "statementDate" => "2017-01-23",
        "subject" => {
          "describedByEntityStatement" => company_id,
        },
        "interestedParty" => {
          "describedByPersonStatement" => unknown_person_id,
        },
        "interests" => [],
      },
    ]
  end
end
