require 'rails_helper'

RSpec.describe ApplicationDecorator do
  class TestModelDecorator < ApplicationDecorator
    decorates :entity # Decorating an existing class to make it easy to test
    # Explicitly not delegating any methods to the model though
    transliterated_attrs :name
  end

  describe '.transliterated_attrs' do
    let(:instance) { create(:entity) }
    let(:decorator) { TestModelDecorator.new(instance) }

    it 'creates a method shadowing the attribute' do
      expect(decorator).to respond_to(:name)
    end

    describe 'generated methods' do
      let(:instance) { create(:entity, name: 'тест', lang_code: 'uk') }

      context 'when should_transliterate is true' do
        let(:decorator) do
          TestModelDecorator.new(
            instance,
            context: { should_transliterate: true },
          )
        end

        it 'returns a transliterated version of the attribute' do
          expect(decorator.name).to eq('test')
        end
      end

      context 'when should_transliterate is false' do
        let(:decorator) do
          TestModelDecorator.new(
            instance,
            context: { should_transliterate: false },
          )
        end

        it 'returns the original attribute' do
          expect(decorator.name).to eq('тест')
        end
      end
    end
  end
end
