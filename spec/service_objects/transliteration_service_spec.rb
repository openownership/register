require 'rails_helper'

RSpec.describe TransliterationService do
  let(:lang_code) { 'foo' }
  let(:rule_set_name) { 'bar' }

  before do
    stub_const(
      'TransliterationService::LANG_CODE_TO_RULE_SETS',
      lang_code => rule_set_name,
    )

    # We need to clear out the instances cache every time
    if TransliterationService.instance_variable_defined?(:@transliterators)
      TransliterationService.remove_instance_variable(:@transliterators)
    end
  end

  describe '.for' do
    context 'with a nil lang_code' do
      let(:lang_code) { nil }

      it 'should still provide a TransliterationService' do
        expect(TransliterationService.for(lang_code)).to be_a TransliterationService
      end
    end

    context 'with a non nil lang_code' do
      it 'should only ever have one instance per lang_code' do
        expect(TransliterationService).to receive(:new)
          .with(lang_code)
          .once
          .and_call_original

        instance = TransliterationService.for(lang_code)
        expect(instance).to be_a TransliterationService

        # And again
        instance_again = TransliterationService.for(lang_code)
        expect(instance_again).to be instance
      end
    end
  end

  describe '#transliterate' do
    let(:value) { 'I am a name' }

    subject do
      TransliterationService.for(lang_code)
    end

    context 'with a nil lang_code' do
      let(:lang_code) { nil }

      it 'should not perform any transliteration on a provided value' do
        expect(TwitterCldr::Transforms::Transformer).to receive(:get).never

        expect(subject.transliterate(value)).to eq value
      end
    end

    context 'with a non nil lang_code' do
      let(:rule_set) { double }
      let(:transliterated_value) { double }

      it 'should use the appropriate rule set to perform transliteration on the value' do
        expect(TwitterCldr::Transforms::Transformer).to receive(:get)
          .with(rule_set_name)
          .and_return(rule_set)
        expect(rule_set).to receive(:transform)
          .with(value)
          .and_return(transliterated_value)

        expect(subject.transliterate(value)).to eq transliterated_value
      end
    end
  end
end
