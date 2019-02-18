require 'rails_helper'

RSpec.describe EntityDecorator do
  describe '#name' do
    context 'when the entity name is blank' do
      let(:decorated) { create(:entity, name: nil).decorate }

      it 'returns the missing name string' do
        expect(decorated.name).to eq(I18n.t('entities.show.company_name_missing'))
      end
    end

    context 'when the entity name is not blank' do
      context 'and should_transliterate is false' do
        let(:decorated) do
          options = { context: { should_transliterate: false } }
          create(:entity, name: 'тест', lang_code: 'uk').decorate(options)
        end

        it 'returns the original name' do
          expect(decorated.name).to eq('тест')
        end
      end

      context 'and should_transliterate is true' do
        let(:decorated) do
          options = { context: { should_transliterate: true } }
          create(:entity, name: 'тест', lang_code: 'uk').decorate(options)
        end

        it 'returns the original name transliterated' do
          expect(decorated.name).to eq('test')
        end
      end
    end
  end
end
