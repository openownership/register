require 'rails_helper'

RSpec.describe EntityHelper do
  describe '#entity_country_flag' do
    subject { helper.entity_country_flag(entity) }

    context 'when the entity has a jurisdiction code' do
      let(:entity) { Entity.new(jurisdiction_code: 'gb') }

      it 'returns the corresponding country flag image' do
        expect(subject).to match(/^<img /)
        expect(subject).to match(%r{src="/assets/GB-.+\.svg"})
        expect(subject).to match(/alt="United Kingdom/)
      end
    end

    context 'when the entity does not have a jurisdiction code' do
      let(:entity) { Entity.new }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when the entity has an unknown jurisdiction code' do
      let(:entity) { Entity.new(jurisdiction_code: 'xxx') }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#entity_jurisdiction' do
    subject { helper.entity_jurisdiction(entity) }

    context 'when the entity has a jurisdiction code' do
      context 'when the jurisdiction matches a country' do
        let(:entity) { Entity.new(jurisdiction_code: 'gb') }

        it 'returns the name of the country' do
          expect(subject).to eq('United Kingdom of Great Britain and Northern Ireland')
        end
      end

      context 'when the jurisdiction matches a subdivision of a country' do
        let(:entity) { Entity.new(jurisdiction_code: 'us_de') }

        it 'returns the name of the subdivision' do
          expect(subject).to eq('Delaware (United States of America)')
        end
      end
    end

    context 'when the entity does not have a jurisdiction code' do
      let(:entity) { Entity.new }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
