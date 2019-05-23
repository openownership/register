require 'rails_helper'

RSpec.describe DataSource do
  let!(:source) { create(:data_source) }
  let!(:statistics) do
    create_list(:data_source_statistic, 2, data_source: source)
  end
  let!(:statistic_types) { statistics.map(&:type) }
  let!(:later_statistics) do
    statistic_types.map do |type|
      create(:data_source_statistic, type: type, data_source: source)
    end
  end

  describe '#statistics_by_type' do
    subject { source.statistics_by_type }

    it 'returns a Hash with Arrays of stats keyed by type' do
      expect(subject).to be_a Hash
      expect(subject.keys.length).to eq statistic_types.length
      statistic_types.each { |t| expect(subject.keys).to include(t) }
      statistic_types.each { |t| expect(subject[t]).to be_a Array }
      statistic_types.each { |t| expect(subject[t].length).to eq(2) }
    end

    context 'when statistics is empty' do
      let(:empty_source) { create(:data_source, statistics: []) }

      subject { empty_source.statistics_by_type }

      it 'returns an empty hash' do
        expect(subject).to eq({})
      end
    end
  end

  describe '#current_statistics' do
    subject { source.current_statistics }

    before do
      # Specify an order that is different to the inserted order
      source.current_statistic_types = statistic_types.shuffle
      source.save!
    end

    it 'returns the latest statistic for each of current_statistic_types' do
      expect(subject).to match_array(later_statistics)
    end

    it 'respects the order of current_statistic_types' do
      returned_types = subject.map(&:type)
      expect(source.current_statistic_types).to eq(returned_types)
    end

    it 'skips missing statistics' do
      # Add a type to current_statistic_types which we don't have a stat for
      source.current_statistic_types << 'missing'
      source.save!
      current_stats = source.current_statistics
      expect(current_stats.find { |s| s.type == 'missing' }).to be_nil
    end
  end
end
