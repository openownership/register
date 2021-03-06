require 'rails_helper'

RSpec.describe UnknownPersonsEntity do
  describe '.new_for_entity' do
    let(:entity) { create(:legal_entity) }

    subject { UnknownPersonsEntity.new_for_entity(entity) }

    it 'gives it an id from the entity id' do
      expected_id = "#{entity.id}-unknown"
      expect(subject.id).to eq expected_id
    end

    it 'has the default reason code' do
      expect(subject.unknown_reason_code).to eq('unknown')
    end

    it 'has the default reason' do
      expect(subject.unknown_reason).to eq(I18n.t("unknown_persons_entity.reasons.totally_unknown"))
    end

    it 'copies the self_updated_at from the entity' do
      expect(subject.self_updated_at).to eq(entity.self_updated_at)
    end
  end

  describe '.new_for_statement' do
    let(:statement) do
      create(:statement, id: { 'identifier' => 'test' }, date: '2019-01-01')
    end

    subject { UnknownPersonsEntity.new_for_statement(statement) }

    it 'gives it an id from the Statement type and the entity id' do
      expected_id = "#{statement.entity.id}-statement-a074553dc232eae63e115296cc404453d51c29567c9039a5c5003dc69cfd81eb"
      expect(subject.id).to eq expected_id
    end

    it 'gives it a reason from the translated description of the Statement type' do
      expected = "The company knows or has reasonable cause to believe that there is no registrable person or registrable relevant legal entity in relation to the company"
      expect(subject.unknown_reason).to eq(expected)
    end

    it 'gives it an unknown_reason_code from the Statement type' do
      expect(subject.unknown_reason_code).to eq('no-individual-or-entity-with-signficant-control')
    end

    it "copies the updated_at from the statement's self_updated_at" do
      expect(subject.self_updated_at).to eq(statement.updated_at)
    end
  end

  describe '#name' do
    it 'returns the known unknown name for no-individual-or-entity-with-signficant-control' do
      entity = UnknownPersonsEntity.new(unknown_reason_code: 'no-individual-or-entity-with-signficant-control')
      expect(entity.name).to eq(I18n.t('unknown_persons_entity.names.no_person'))
    end

    it 'returns the default unknown name for everything else' do
      entity = UnknownPersonsEntity.new(unknown_reason_code: 'unknown')
      expect(entity.name).to eq(I18n.t('unknown_persons_entity.names.unknown'))
    end
  end
end
