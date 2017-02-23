require 'rails_helper'

RSpec.describe EntityHelper do
  describe '#entity_country_flag' do
    context 'when the entity has a jurisdiction code' do
      subject { Entity.new(jurisdiction_code: 'gb') }

      it 'returns the corresponding country flag image' do
        image = helper.entity_country_flag(subject)

        expect(image).to match(/^<img /)
        expect(image).to match(%r{src="/assets/GB-.+\.svg"})
        expect(image).to match(/alt="United Kingdom/)
      end
    end

    context 'when the entity does not have a jurisdiction code' do
      subject { Entity.new }

      it 'returns nil' do
        expect(helper.entity_country_flag(subject)).to be_nil
      end
    end

    context 'when the entity has an unknown jurisdiction code' do
      subject { Entity.new(jurisdiction_code: 'xxx') }

      it 'returns nil' do
        expect(helper.entity_country_flag(subject)).to be_nil
      end
    end
  end

  describe '#entity_jurisdiction' do
    context 'when the entity has a jurisdiction code' do
      context 'when the jurisdiction matches a country' do
        subject { Entity.new(jurisdiction_code: 'gb') }

        it 'returns the name of the country' do
          expect(helper.entity_jurisdiction(subject)).to eq('United Kingdom of Great Britain and Northern Ireland')
        end
      end

      context 'when the jurisdiction matches a subdivision of a country' do
        subject { Entity.new(jurisdiction_code: 'us_de') }

        it 'returns the name of the subdivision' do
          expect(helper.entity_jurisdiction(subject)).to eq('Delaware (United States of America)')
        end
      end
    end

    context 'when the entity does not have a jurisdiction code' do
      subject { Entity.new }

      it 'returns nil' do
        expect(helper.entity_jurisdiction(subject)).to be_nil
      end
    end
  end
end
