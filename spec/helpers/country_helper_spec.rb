require 'rails_helper'

RSpec.describe CountryHelper do
  let(:country) { ISO3166::Country[:GB] }

  describe '#country_flag' do
    subject { helper.country_flag(country) }

    it 'returns the corresponding country flag image' do
      expect(subject).to match(/^<img /)
      expect(subject).to match(%r{src="/assets/GB-.+\.svg"})
      expect(subject).to match(/alt="United Kingdom/)
    end

    context 'when the country is nil' do
      let(:country) { nil }

      it 'returns the unknown flag image' do
        expect(subject).to match(/^<img /)
        expect(subject).to match(%r{src="/assets/flag-unknown-.+\.svg"})
        expect(subject).to match(/alt="unknown"/)
      end
    end
  end
end
