require 'rails_helper'

RSpec.describe EntityHelper do
  let(:entity) { Entity.new }

  describe '#entity_country_flag' do
    subject { helper.entity_country_flag(entity) }

    context 'when the entity has a country' do
      before { allow(entity).to receive(:country).and_return(ISO3166::Country[:GB]) }

      it 'returns the corresponding country flag image' do
        expect(subject).to match(/^<img /)
        expect(subject).to match(%r{src="/assets/GB-.+\.svg"})
        expect(subject).to match(/alt="United Kingdom/)
      end
    end

    context 'when the entity does not have a country' do
      before { allow(entity).to receive(:country).and_return(nil) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#entity_jurisdiction' do
    subject { helper.entity_jurisdiction(entity) }

    context 'when the entity has a country' do
      context 'when the entity does not have a subdivision' do
        before { allow(entity).to receive(:country).and_return(ISO3166::Country[:GB]) }
        before { allow(entity).to receive(:country_subdivision).and_return(nil) }

        it 'returns the name of the country' do
          expect(subject).to eq('United Kingdom of Great Britain and Northern Ireland')
        end
      end

      context 'when the jurisdiction matches a subdivision of a country' do
        before { allow(entity).to receive(:country).and_return(ISO3166::Country[:US]) }
        before { allow(entity).to receive(:country_subdivision).and_return(ISO3166::Country[:US].subdivisions["DE"]) }

        it 'returns the name of the subdivision' do
          expect(subject).to eq('Delaware (United States of America)')
        end
      end
    end

    context 'when the entity does not have a country' do
      before { allow(entity).to receive(:country).and_return(nil) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
