require 'rails_helper'

RSpec.describe BodsImporter do
  let(:opencorporates_client) { instance_double('OpencorporatesClient') }
  let(:entity_resolver) { instance_double('EntityResolver') }
  let(:index_entity_service) { instance_double('IndexEntityService') }
  let(:company_number_extractor) { double }
  let(:source_name) { 'Test BODS Source' }
  let(:source_url) { 'https://example.com/bods.json' }
  let(:retrieved_at) { Time.zone.local(2011, 2, 3, 4, 5, 6) }
  let(:document_id) { 'Test BODS Import' }

  subject do
    importer = BodsImporter.new(
      opencorporates_client: opencorporates_client,
      entity_resolver: entity_resolver,
      company_number_extractor: company_number_extractor,
    )
    importer.source_url = source_url
    importer.source_name = source_name
    importer.retrieved_at = retrieved_at
    importer.document_id = document_id
    importer
  end

  describe '#process_records' do
    it 'requires a statementID for each record' do
      records = JSON.parse(file_fixture('bods_legal_entity.json').read)
      records.first.delete('statementID')
      error = /^Missing statementID/
      expect { subject.process_records(records) }.to raise_exception(error)
    end

    it 'requires a statementType for each record' do
      records = JSON.parse(file_fixture('bods_legal_entity.json').read)
      records.first.delete('statementType')
      error = /^Missing statementType in statement/
      expect { subject.process_records(records) }.to raise_exception(error)
    end

    context 'Entity statements' do
      let(:records) { JSON.parse(file_fixture('bods_legal_entity.json').read) }
      let(:statement_id) { '1dc0e987-5c57-4a1c-b3ad-61353b66a9b7' }
      let(:company_number) { '01234567' }

      before do
        allow(company_number_extractor).to receive(:extract).and_return(company_number)
        allow(entity_resolver).to receive(:resolve!)

        allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
        allow(index_entity_service).to receive(:index)
      end

      it 'creates a Legal Entity, mapping the fields to our DB' do
        expect do
          subject.process_records(records)
        end.to change { Entity.count }.by(1)
        entity = Entity.find_by('identifiers.statement_id' => statement_id)
        expected_identifiers = [
          {
            'document_id' => document_id,
            'statement_id' => statement_id,
          },
          {
            'scheme' => 'GB-COH',
            'id' => company_number,
          },
        ]
        expect(entity.identifiers).to match_array expected_identifiers
        expect(entity.type).to eq Entity::Types::LEGAL_ENTITY
        expect(entity.name).to eq 'EXAMPLE LTD'
        expect(entity.incorporation_date.iso8601).to eq '2015-01-01'
        expect(entity.company_type).to be_nil
        expect(entity.jurisdiction_code).to eq 'GB'
        expect(entity.address).to eq '1, Example Street, Example City, EX4 3PL'
      end

      it 'imports data from statements missing optional fields' do
        records = JSON.parse(file_fixture('bods_bare_minimum_legal_entity.json').read)
        subject.process_records(records)
        entity = Entity.where('identifiers.statement_id' => records.first['statementID'])
        expect(entity).to exist
      end

      context 'resolving with OpenCorporates' do
        it "resolves the entity with OpenCorporates" do
          expect(entity_resolver).to receive(:resolve!)
          subject.process_records(records)
        end
      end

      it 'indexes the entity' do
        expect(index_entity_service).to receive(:index)
        subject.process_records(records)
      end

      context "statementIDs we've seen before" do
        it "doesn't try to update details for existing entities" do
          subject.process_records(records)
          entity = Entity.find_by('identifiers.statement_id' => statement_id)
          records.first["name"] = 'UPDATED LTD'
          expect { subject.process_records(records) }.not_to change { entity.reload.name }
        end

        it 'still resolves with OpenCorporates' do
          expect(entity_resolver).to receive(:resolve!).exactly(2).times
          subject.process_records(records)
          subject.process_records(records)
        end
      end

      context "Dealing with race conditions where the entity already exists " \
              "on save but wasn't found earlier" do
        it 'skips over records when they already exist in the database' do
          # Entity resolution comes after we look for existing records, so if we
          # create an entity here, it should cause a problem when we try to save
          # the 'resolved' record.
          expect(entity_resolver).to receive(:resolve!) do
            Entity.create!(
              identifiers: [
                { 'document_id' => document_id, 'statement_id' => statement_id },
                { 'scheme' => 'GB-COH', 'id' => company_number },
              ],
              type: Entity::Types::LEGAL_ENTITY,
            )
          end
          subject.process_records(records)
          expect(Entity.where('identifiers.statement_id' => statement_id).count).to eq 1
        end
      end

      context 'specific field details' do
        it 'requires an entityType' do
          records.first.delete('entityType')
          error = /^Missing entityType in statement/
          expect { subject.process_records(records) }.to raise_exception(error)
        end

        context 'mapping identifiers' do
          it 'maps identifiers using their scheme if available' do
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.identifiers).to include('scheme' => 'GB-COH', 'id' => company_number)
          end

          it 'falls back to the schemeName if scheme is missing' do
            extra_identifier = {
              'schemeName' => 'Test Identifiers',
              'id' => '1234567',
            }
            records.first['identifiers'] << extra_identifier
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.identifiers).to include('scheme_name' => 'Test Identifiers', 'id' => '1234567')
          end

          it 'raises an error if neither scheme or schemeName is present' do
            bad_identifier = { 'id' => '1234567' }
            records.first['identifiers'] << bad_identifier
            error = /No identifier scheme or schemeName given/
            expect { subject.process_records(records) }.to raise_exception(error)
          end
        end

        context 'mapping jurisdictions' do
          context "when there's an ISO 3166-2 sub-jurisdiction code" do
            it "uses the first two digits of that code" do
              records.first['incorporatedInJurisdiction']['code'] = 'GB-EAW'
              subject.process_records(records)
              entity = Entity.find_by('identifiers.statement_id' => statement_id)
              expect(entity.jurisdiction_code).to eq('GB')
            end
          end

          context "when there's no code" do
            it "resolves the jurisdiction name with OpenCorporates" do
              records.first['incorporatedInJurisdiction'].delete('code')
              expect(opencorporates_client)
                .to(receive(:get_jurisdiction_code))
                .with('United Kingdom')
                .and_return('GB')
              subject.process_records(records)
              entity = Entity.find_by('identifiers.statement_id' => statement_id)
              expect(entity.jurisdiction_code).to eq('GB')
            end
          end

          it "sets the jurisdiction to nil if there's no code or name" do
            records.first['incorporatedInJurisdiction'].delete('code')
            records.first['incorporatedInJurisdiction'].delete('name')
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.jurisdiction_code).to be_nil
          end
        end

        context 'mapping addresses' do
          it 'selects the registered address if there is one' do
            other_address = {
              'type' => 'service',
              'address' => '1a Example Cottages, Example Road, Example',
              'country' => 'EX',
              'postCode' => 'EX4 MP1',
            }
            records.first['addresses'] << other_address
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.address).to eq '1, Example Street, Example City, EX4 3PL'
          end

          it 'picks the first registered address if there are several' do
            other_address = {
              'type' => 'registered',
              'address' => '1a Example Cottages, Example Road, Example',
              'country' => 'EX',
              'postCode' => 'EX4 MP1',
            }
            records.first['addresses'] << other_address
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.address).to eq '1, Example Street, Example City, EX4 3PL'
          end

          it 'leaves it blank when there are no registered addresses' do
            records.first['addresses'].first['type'] = 'home'
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.address).to be_nil
          end
        end

        it 'uses the extractor provided to obtain a company number' do
          expect(company_number_extractor)
            .to(receive(:extract))
            .with(records.first['identifiers'])
            .and_return(company_number)
          subject.process_records(records)
        end

        context 'dealing with approximate datetimes' do
          it 'reduces datetime incorporation_dates to dates' do
            records.first['foundingDate'] = '2019-01-01T00:00:00Z'
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.incorporation_date.iso8601).to eq('2019-01-01')
          end

          it 'reduces datetime dissolution_dates to dates' do
            records.first['dissolutionDate'] = '2019-01-01T00:00:00Z'
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.dissolution_date.iso8601).to eq('2019-01-01')
          end
        end
      end
    end

    context 'Person statements' do
      let(:records) { JSON.parse(file_fixture('bods_natural_person.json').read) }
      let(:statement_id) { '019a93f1-e470-42e9-957b-03559861b2e2' }
      let(:passport_number) { '1234567' }

      before do
        allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
        allow(index_entity_service).to receive(:index)
      end

      it 'creates a Natural person, mapping the fields to our DB' do
        expect do
          subject.process_records(records)
        end.to change { Entity.count }.by(1)
        entity = Entity.find_by('identifiers.statement_id' => statement_id)
        expected_identifiers = [
          { 'document_id' => document_id, 'statement_id' => statement_id },
          { 'scheme' => 'GB-PASSPORT', 'id' => passport_number },
        ]
        expect(entity.identifiers).to match_array expected_identifiers
        expect(entity.type).to eq Entity::Types::NATURAL_PERSON
        expect(entity.name).to eq 'First Last'
        expect(entity.dob).to eq ISO8601::Date.new('1960-01-01')
        expect(entity.nationality).to eq 'GB'
        expect(entity.country_of_residence).to eq 'GB'
        expect(entity.address).to eq '1, Example Street, Example City, EX4 3PL'
      end

      it 'imports data from statements missing optional fields' do
        records = JSON.parse(file_fixture('bods_bare_minimum_natural_person.json').read)
        subject.process_records(records)
        entity = Entity.where('identifiers.statement_id' => records.first['statementID'])
        expect(entity).to exist
      end

      context "statementIDs we've seen before" do
        it "doesn't try to update details for existing entities" do
          subject.process_records(records)
          entity = Entity.find_by('identifiers.statement_id' => statement_id)
          records.first["name"] = 'UPDATED PERSON'
          expect { subject.process_records(records) }.not_to change { entity.reload.name }
        end
      end

      context "Dealing with race conditions where the entity already exists " \
              "on save but wasn't found earlier" do
        it 'skips over records when they already exist in the database' do
          # Create a duplicate record, and then stub the exists? method to
          # falsely report no entities, because we don't have anywhere else to
          # cause a race condition
          Entity.create!(
            identifiers: [
              { 'document_id' => document_id, 'statement_id' => statement_id },
              { 'scheme' => 'GB-PASSPORT', 'id' => passport_number },
            ],
            type: Entity::Types::NATURAL_PERSON,
          )
          criteria = instance_double(Mongoid::Criteria)
          allow(criteria).to receive(:exists?).and_return(false)
          allow(Entity).to receive(:where).and_call_original
          allow(Entity).to receive(:where)
            .with('identifiers.statement_id' => statement_id)
            .and_return(criteria)

          subject.process_records(records)

          # Remove the stub so we can test
          allow(Entity).to receive(:where)
            .with('identifiers.statement_id' => statement_id)
            .and_call_original

          expect(Entity.where('identifiers.statement_id' => statement_id).count).to eq 1
        end
      end

      it 'indexes the entity' do
        expect(index_entity_service).to receive(:index)
        subject.process_records(records)
      end

      context 'field specific details' do
        context 'mapping names' do
          it 'uses the individual name if there is one' do
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.name).to eq('First Last')
            # Not the 'aka' name that's in the data too
          end
          it 'uses the first individual name if there are several' do
            other_name = {
              'type' => 'individual',
              'fullName' => 'John Smith',
            }
            records.first['names'] << other_name
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.name).to eq('First Last')
          end

          it 'leaves it blank when there are no individual names' do
            records.first['names'].first['type'] = 'former'
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.name).to be_nil
          end
        end

        context 'mapping nationalities' do
          it "uses the first nationality if there's more than one" do
            other_nationality = {
              code: 'US',
              name: 'United States',
            }
            records.first['nationalities'] << other_nationality
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.nationality).to eq('GB')
          end

          it "returns the country code if it's given" do
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.nationality).to eq('GB')
          end

          it "looks up the country code from the name if the code isn't given" do
            records.first['nationalities'].first.delete('code')
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.nationality).to eq('GB')
          end

          it "sets the jurisdiction to nil if there's no code or name" do
            records.first['nationalities'].first.delete('code')
            records.first['nationalities'].first.delete('name')
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.nationality).to be_nil
          end
        end

        it 'reduces datetime dates of birth to dates' do
          records.first['birthDate'] = '2019-01-01T00:00:00Z'
          subject.process_records(records)
          entity = Entity.find_by('identifiers.statement_id' => statement_id)
          expect(entity.dob).to eq ISO8601::Date.new('2019-01-01')
        end

        context 'mapping addresses' do
          it 'selects the service address if there is one' do
            other_address = {
              'type' => 'residence',
              'address' => '1a Example Cottages, Example Road, Example',
              'country' => 'EX',
              'postCode' => 'EX4 MP1',
            }
            records.first['addresses'] << other_address
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.address).to eq '1, Example Street, Example City, EX4 3PL'
          end

          it 'picks the first service address if there are several' do
            other_address = {
              'type' => 'service',
              'address' => '1a Example Cottages, Example Road, Example',
              'country' => 'EX',
              'postCode' => 'EX4 MP1',
            }
            records.first['addresses'] << other_address
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.address).to eq '1, Example Street, Example City, EX4 3PL'
          end

          it 'leaves the address blank if there are no service addresses' do
            records.first['addresses'].first['type'] = 'residence'
            subject.process_records(records)
            entity = Entity.find_by('identifiers.statement_id' => statement_id)
            expect(entity.address).to be_nil
          end
        end
      end
    end

    context 'Ownership or control statements' do
      let(:records) { JSON.parse(file_fixture('bods_ownership.json').read) }
      let(:statement_id) { 'fbfd0547-d0c6-4a00-b559-5c5e91c34f5c' }
      let(:source) { Entity.find_by('identifiers.statement_id' => '019a93f1-e470-42e9-957b-03559861b2e2') }
      let(:target) { Entity.find_by('identifiers.statement_id' => '1dc0e987-5c57-4a1c-b3ad-61353b66a9b7') }

      before do
        company_records = JSON.parse(file_fixture('bods_legal_entity.json').read)
        person_records = JSON.parse(file_fixture('bods_natural_person.json').read)
        allow(company_number_extractor).to receive(:extract).and_return('1234567')
        allow(entity_resolver).to receive(:resolve!)
        allow(IndexEntityService).to receive(:new).and_return(index_entity_service)
        allow(index_entity_service).to receive(:index)
        subject.process_records(company_records + person_records)
      end

      it 'creates a Relationship, mapping the fields to our DB' do
        expect do
          subject.process_records(records)
        end.to change { Relationship.count }.by(1)
        relationship = Relationship.find_by('_id.statement_id' => statement_id)
        expect(relationship.source).to eq source
        expect(relationship.target).to eq target
        expected_interests = [
          {
            'type' => 'shareholding',
            'share_min' => 100,
            'share_max' => 100,
          },
        ]
        expect(relationship.interests).to eq expected_interests
        expect(relationship.started_date).to eq ISO8601::Date.new('2015-01-01')
        expect(relationship.ended_date).to be_nil
        expect(relationship.sample_date).to eq ISO8601::Date.new('2015-01-01')
        expect(relationship.provenance.source_url).to eq source_url
        expect(relationship.provenance.source_name).to eq source_name
        expect(relationship.provenance.retrieved_at).to eq retrieved_at
        expect(relationship.provenance.imported_at).to be_within(1.second).of(Time.now.utc)
      end

      context "when the interestedParty is unspecified" do
        let(:records) { JSON.parse(file_fixture('bods_unspecified_ownership.json').read) }
        let(:statement_id) { 'fbfd0547-d0c6-4a00-b559-5c5e91c34f5e' }

        it "creates a Statement, mapping the fields to the DB" do
          expect do
            subject.process_records(records)
          end.to change { Statement.count }.by(1)
          statement = Statement.find_by('_id.statement_id' => statement_id)
          expect(statement.entity).to eq target
          expect(statement.type).to eq 'no-beneficial-owners'
          expect(statement.ended_date).to be_nil
          expect(statement.date.iso8601).to eq '2015-01-01'
        end
      end

      it 'imports data from statements missing optional fields' do
        records = JSON.parse(file_fixture('bods_bare_minimum_ownership.json').read)
        statement_id = 'fbfd0547-d0c6-4a00-b559-5c5e91c34f5d'
        expect do
          subject.process_records(records)
        end.to change { Relationship.count }.by(1)
        relationship = Relationship.find_by('_id.statement_id' => statement_id)
        expect(relationship.source).to eq source
        expect(relationship.target).to eq target
        expect(relationship.interests).to eq []
        expect(relationship.started_date).to be_nil
        expect(relationship.ended_date).to be_nil
        expect(relationship.sample_date).to be_nil
        expect(relationship.provenance.source_url).to eq source_url
        expect(relationship.provenance.source_name).to eq source_name
        expect(relationship.provenance.retrieved_at).to eq retrieved_at
        expect(relationship.provenance.imported_at).to be_within(1.second).of(Time.now.utc)
      end

      context "statementIDs we've seen before" do
        it "doesn't try to update details for existing Relationships" do
          subject.process_records(records)
          relationship = Relationship.find_by('_id.statement_id' => statement_id)
          records.first["statementDate"] = '2019-04-29'
          expect do
            subject.process_records(records)
          end.not_to change { relationship.reload.sample_date }
        end

        it "doesn't try to update details for existing Statements" do
          records = JSON.parse(file_fixture('bods_unspecified_ownership.json').read)
          statement_id = 'fbfd0547-d0c6-4a00-b559-5c5e91c34f5e'
          subject.process_records(records)
          statement = Statement.find_by('_id.statement_id' => statement_id)
          records.first["statementDate"] = '2019-04-29'
          expect do
            subject.process_records(records)
          end.not_to change { statement.reload.date }
        end
      end

      context "Dealing with race conditions where the relationship already " \
              "exists on save but wasn't found earlier" do
        it 'skips over Relationships when they already exist in the database' do
          # Create a duplicate record, and then stub the exists? method to
          # falsely report no entities, because we don't have anywhere else to
          # cause a race condition
          Relationship.create!(
            _id: {
              'document_id' => document_id,
              'statement_id' => statement_id,
            },
            source: source,
            target: target,
          )
          criteria = instance_double(Mongoid::Criteria)
          allow(criteria).to receive(:exists?).and_return(false)
          allow(Relationship).to receive(:where).and_call_original
          allow(Relationship).to receive(:where)
            .with('_id.statement_id' => statement_id)
            .and_return(criteria)

          subject.process_records(records)

          # Remove the stub so we can test
          allow(Relationship).to receive(:where)
            .with('_id.statement_id' => statement_id)
            .and_call_original

          expect(Relationship.where('_id.statement_id' => statement_id).count).to eq 1
        end

        it 'skips over Statements when they already exist in the database' do
          # Create a duplicate record, and then stub the exists? method to
          # falsely report no entities, because we don't have anywhere else to
          # cause a race condition
          Statement.create!(
            _id: {
              'document_id' => document_id,
              'statement_id' => statement_id,
            },
            entity: target,
          )
          criteria = instance_double(Mongoid::Criteria)
          allow(criteria).to receive(:exists?).and_return(false)
          allow(Statement).to receive(:where).and_call_original
          allow(Statement).to receive(:where)
            .with('_id.statement_id' => statement_id)
            .and_return(criteria)

          subject.process_records(records)

          # Remove the stub so we can test
          allow(Statement).to receive(:where)
            .with('_id.statement_id' => statement_id)
            .and_call_original

          expect(Statement.where('_id.statement_id' => statement_id).count).to eq 1
        end
      end

      context 'field specific details' do
        it 'requires a subject' do
          records.first.delete('subject')
          error = "Missing subject in statement: #{statement_id}"
          expect { subject.process_records(records) }.to raise_error(error)
        end

        it 'requires an interestedParty' do
          records.first.delete('interestedParty')
          error = "Missing interestedParty in statement: #{statement_id}"
          expect { subject.process_records(records) }.to raise_error(error)
        end

        context 'finding the subject (child entity)' do
          it 'raises an error if describedByEntityStatement is missing' do
            records.first['subject']['describedByEntityStatement'] = nil
            error = "No describedByEntityStatement (child entity) given " \
                    "in statement: #{statement_id}"
            expect { subject.process_records(records) }.to raise_error(error)
          end
        end

        context 'finding the interested party (parent entity)' do
          it 'errors if more than one interested party is supplied' do
            # describedByPersonStatement already exists
            records.first['interestedParty']['describedByEntityStatement'] = '1dc0e987-5c57-4a1c-b3ad-61353b66a9b7'
            error = "More than one interestedParty specified in " \
                    "statement: #{statement_id}"
            expect { subject.process_records(records) }.to raise_error(error)
          end
        end

        context 'mapping interests' do
          context 'when there is no share object' do
            it 'creates String interests from the type' do
              records.first['interests'].first.delete('share')
              subject.process_records(records)
              relationship = Relationship.find_by('_id.statement_id' => statement_id)
              expect(relationship.interests).to eq ['shareholding']
            end
          end

          context 'when there is a share object' do
            context "when the share is exact" do
              it 'creates Hash interests, mapping the exact share to min/max properties' do
                records.first['interests'].first['share'].delete('minimum')
                records.first['interests'].first['share'].delete('maximum')
                subject.process_records(records)
                relationship = Relationship.find_by('_id.statement_id' => statement_id)
                expected_interests = [
                  {
                    'type' => 'shareholding',
                    'share_min' => 100,
                    'share_max' => 100,
                  },
                ]
                expect(relationship.interests).to match_array(expected_interests)
              end
            end

            context 'when the share is a range' do
              it 'creates Hash interests, copying the min/max properties' do
                extra_interest = {
                  "type" => "voting-rights",
                  "interestLevel" => "direct",
                  "beneficialOwnershipOrControl" => true,
                  "startDate" => "2016-04-06",
                  "share" => {
                    "minimum" => 50,
                    "maximum" => 75,
                    "exclusiveMin" => true,
                    "exclusiveMax" => false,
                  },
                }
                records.first['interests'] << extra_interest
                subject.process_records(records)
                relationship = Relationship.find_by('_id.statement_id' => statement_id)
                expected_interests = [
                  {
                    'type' => 'shareholding',
                    'share_min' => 100,
                    'share_max' => 100,
                  },
                  {
                    'type' => 'voting-rights',
                    'share_min' => 50,
                    'share_max' => 75,
                    "exclusive_min" => true,
                    "exclusive_max" => false,
                  },
                ]
                expect(relationship.interests).to match_array(expected_interests)
              end

              it 'defaults exclusiveMin to false and exclusiveMax to true' do
                interest_without_exclusive_min_max = {
                  "type" => "voting-rights",
                  "interestLevel" => "direct",
                  "beneficialOwnershipOrControl" => true,
                  "startDate" => "2016-04-06",
                  "share" => {
                    "minimum" => 50,
                    "maximum" => 75,
                    "exclusiveMin" => false,
                    "exclusiveMax" => true,
                  },
                }
                records.first['interests'][0] = interest_without_exclusive_min_max
                subject.process_records(records)
                relationship = Relationship.find_by('_id.statement_id' => statement_id)
                expected_interests = [
                  {
                    'type' => 'voting-rights',
                    'share_min' => 50,
                    'share_max' => 75,
                    "exclusive_min" => false,
                    "exclusive_max" => true,
                  },
                ]
                expect(relationship.interests).to match_array(expected_interests)
              end
            end
          end
        end

        context 'mapping start and end dates' do
          it 'sets the Relationship start date to the earliest interest start date' do
            later_interest = {
              "type" => "voting-rights",
              "interestLevel" => "direct",
              "beneficialOwnershipOrControl" => true,
              "startDate" => "2019-04-29",
              "share" => {
                "minimum" => 50,
                "maximum" => 75,
              },
            }
            undated_interest = {
              "type" => "voting-rights",
              "interestLevel" => "direct",
            }
            records.first['interests'] << later_interest
            records.first['interests'] << undated_interest
            subject.process_records(records)
            relationship = Relationship.find_by('_id.statement_id' => statement_id)
            expect(relationship.started_date).to eq ISO8601::Date.new('2015-01-01')
          end

          context 'if all the interests have ended' do
            it 'sets the Relationship end date to the latest interest end date' do
              records.first['interests'].first['endDate'] = '2019-01-01'
              latest_ended_interest = {
                "type" => "voting-rights",
                "startDate" => "2019-03-29",
                "endDate" => "2019-04-29",
              }
              records.first['interests'] << latest_ended_interest
              subject.process_records(records)
              relationship = Relationship.find_by('_id.statement_id' => statement_id)
              expect(relationship.ended_date).to eq ISO8601::Date.new('2019-04-29')
            end
          end
        end
      end

      context 'dealing with missing dependencies' do
        context 'on the first pass for a record' do
          context 'when the subject is not in the database' do
            before do
              target.destroy!
            end

            it 'schedules a new import job for the record' do
              allow(company_number_extractor).to receive(:schemes).and_return(['GB-COH'])
              expect(BodsChunkImportRetryWorker).to receive(:perform_async) do |chunk|
                scheduled_record = JSON.parse(ChunkHelper.from_chunk(chunk).first)
                expect(scheduled_record['retried']).to be true
              end
              expect do
                subject.process_records(records)
              end.not_to change { Relationship.count }
            end
          end

          context 'when the interestedParty is not in the database' do
            before do
              source.destroy!
            end

            it 'schedules a new import job for the record' do
              allow(company_number_extractor).to receive(:schemes).and_return(['GB-COH'])
              expect(BodsChunkImportRetryWorker).to receive(:perform_async) do |chunk|
                scheduled_record = JSON.parse(ChunkHelper.from_chunk(chunk).first)
                expect(scheduled_record['retried']).to be true
              end
              expect do
                subject.process_records(records)
              end.not_to change { Relationship.count }
            end
          end
        end

        context 'on the second pass for a record' do
          let(:expected_error) do
            "Cannot find dependent records for statement: #{records.first['statementID']} on retry"
          end

          before do
            records.first['retried'] = true
          end

          context 'when the subject is not in the database' do
            before do
              target.destroy!
            end

            it 'raises an error' do
              expect { subject.process_records(records) }.to raise_error(expected_error)
            end
          end

          context 'when the interestedParty is not in the database' do
            before do
              source.destroy!
            end

            it 'raises an error' do
              expect { subject.process_records(records) }.to raise_error(expected_error)
            end
          end
        end
      end
    end
  end
end
