require 'rails_helper'

RSpec.describe CountryHelper do
  let(:country) { ISO3166::Country[:GB] }

  describe '#country_flag' do
    subject { helper.country_flag(country) }

    it 'returns the corresponding country flag image' do
      expect(subject).to match(/^<img /)
      expect(subject).to match(%r{src="/assets/GB.*\.svg"})
      expect(subject).to match(/alt="United Kingdom/)
    end

    context 'when the country is nil' do
      let(:country) { nil }

      it 'returns a glossary tooltip with unknown flag image' do
        expect(helper).to receive(:glossary_tooltip).and_call_original
        expect(subject).to match(/<img /)
        expect(subject).to match(%r{src="/assets/flag-unknown.*\.svg"})
        expect(subject).to match(/alt="unknown"/)
      end
    end
  end

  describe "#country_flag_path" do
    subject { helper.country_flag_path(country) }

    it 'returns the corresponding country flag image path' do
      expect(subject).to match(%r{/assets/GB.*\.svg})
    end

    context 'when the country is nil' do
      let(:country) { nil }

      it 'returns a glossary tooltip with unknown flag image' do
        expect(subject).to match(%r{/assets/flag-unknown.*\.svg})
      end
    end
  end
end
