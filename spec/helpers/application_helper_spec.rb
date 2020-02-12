require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#partial_date_format' do
    subject { helper.partial_date_format(date) }

    context 'when the date has a year' do
      let(:date) { ISO8601::Date.new('2017') }

      it 'returns a string containing the year' do
        expect(subject).to eq('2017')
      end
    end

    context 'when the date has a year and a month' do
      let(:date) { ISO8601::Date.new('2017-03') }

      it 'returns a string containing the year and the month' do
        expect(subject).to eq('2017-03')
      end
    end

    context 'when the date has a year and a month and a day' do
      let(:date) { ISO8601::Date.new('2017-03-13') }

      it 'returns a string containing the year and the month and the day' do
        expect(subject).to eq('2017-03-13')
      end
    end

    context 'when the date is nil' do
      let(:date) { nil }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#render_haml' do
    it 'escapes HTML chars' do
      @xss = '<script>alert("pwn");</script>'
      haml = '%span= @xss'
      expected = "<span>&lt;script&gt;alert(&quot;pwn&quot;);&lt;/script&gt;</span>\n"
      expect(helper.render_haml(haml)).to eq(expected)
    end
  end
end
