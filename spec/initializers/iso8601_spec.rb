require 'rails_helper'

RSpec.describe ISO8601::Date do
  describe '#mongoize' do
    context 'when given an ISO8601::Date' do
      it 'returns a string' do
        iso_date = ISO8601::Date.new('2019-01-01')
        expect(ISO8601::Date.mongoize(iso_date)).to eq('2019-01-01')
      end
    end

    context 'when given a string' do
      it 'returns an ISO8601::Date formatted string' do
        expect(ISO8601::Date.mongoize('2019-01-01')).to eq('2019-01-01')
      end
    end

    context 'when given nil' do
      it 'returns nil' do
        expect(ISO8601::Date.mongoize(nil)).to be_nil
      end
    end

    context 'when given anything else' do
      it 'raises an error' do
        date = Date.new(2019, 1, 1)
        error = 'Unable to mongoize Date 2019-01-01 as ISO8601::Date'
        expect { ISO8601::Date.mongoize(date) }.to raise_exception(error)
      end
    end
  end

  describe '#demongoize' do
    context 'when the string is blank' do
      it 'returns nil' do
        expect(ISO8601::Date.demongoize('')).to be_nil
      end
    end

    context 'when the string is not blank' do
      it 'returns a new ISO8601::Date instance' do
        expect(ISO8601::Date.demongoize('2019-01-01')).to be_a(ISO8601::Date)
      end
    end
  end
end
