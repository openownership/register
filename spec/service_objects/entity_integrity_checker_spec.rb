require 'rails_helper'

RSpec.describe EntityIntegrityChecker do
  describe '#check_all' do
    let!(:entities) { create_list :legal_entity, 3 }

    it 'checks all the entities in the system and outputs stats' do
      expect(subject).to receive(:check)
        .with(entities[0])
        .and_return(foo: {})

      expect(subject).to receive(:check)
        .with(entities[1])
        .and_return({})

      expect(subject).to receive(:check)
        .with(entities[2])
        .and_return(foo: {}, bar: {})

      stats = {
        entity_count: 3,
        processed: 3,
        foo: 2,
        bar: 1,
      }

      expect(Rails.logger).to receive(:info)
        .with("[EntityIntegrityChecker] check_all finished with stats: #{stats.to_json}")

      expect(subject.check_all).to eq stats
    end
  end

  describe '#check' do
    context 'a legal entity with no integrity issues' do
      let! :entity do
        e = create :legal_entity
        e.add_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: e.company_number,
        )
        create :relationship, target: e
        e
      end

      it 'should return an empty Hash' do
        expect(subject.check(entity)).to eq({})
      end
    end

    context 'a legal entity with no OC identifier' do
      let! :entity do
        e = create :legal_entity
        create :relationship, target: e
        e
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(no_oc_identifier: {})
      end
    end

    context 'a legal entity with multiple OC identifiers' do
      let! :entity do
        e = create :legal_entity
        e.add_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: '12345',
        )
        e.add_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: '6789',
        )
        create :relationship, target: e
        e
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(
          multiple_oc_identifiers: {
            oc_identifiers_count: 2,
            unique_oc_identifiers_count: 2,
            oc_identifiers: [
              { 'jurisdiction_code' => 'gb', 'company_number' => '12345' },
              { 'jurisdiction_code' => 'gb', 'company_number' => '6789' },
            ],
            company_number_set_on_record: entity.company_number,
          },
          multiple_company_numbers: {
            company_numbers: [entity.company_number, '12345', '6789'].sort,
          },
        )
      end
    end

    context 'an entity with a PSC self link identifier that should have a company number but doesn\'t' do
      let! :entity do
        e = create :legal_entity, company_number: '1234'
        e.add_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: '1234',
        )
        e.identifiers << {
          'document_id' => 'GB PSC Snapshot',
          'link' => 'uri://foo',
        }
        create :relationship, target: e
        e
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(
          self_link_missing_company_number: { count: 1 },
        )
      end
    end

    context 'a legal entity with no company_number field set' do
      let! :entity do
        e = create :legal_entity, company_number: nil
        e.add_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: '12345',
        )
        create :relationship, target: e
        e
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(missing_company_number_field: {})
      end
    end

    context 'a legal entity with no company number set' do
      let! :entity do
        e = create :legal_entity, company_number: nil
        create :relationship, target: e
        e
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(
          no_oc_identifier: {},
          missing_company_number_field: {},
          no_company_number_at_all: {},
        )
      end
    end

    context 'a legal entity with multiple company numbers set' do
      let! :entity do
        e = create :legal_entity, company_number: '12345'
        e.add_oc_identifier(
          jurisdiction_code: 'gb',
          company_number: 'AAAAA',
        )
        create :relationship, target: e
        e
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(
          multiple_company_numbers: {
            company_numbers: %w[12345 AAAAA],
          },
        )
      end
    end

    context 'an entity with no relationships' do
      let! :entity do
        create :natural_person
      end

      it 'should return a Hash with an appropriate check result' do
        expect(subject.check(entity)).to eq(
          no_relationships: { type: 'natural-person' },
        )
      end
    end
  end
end
