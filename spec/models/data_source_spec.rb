require 'rails_helper'

RSpec.describe DataSource do
  let!(:source) { create(:data_source) }
  let!(:statistics) do
    stats = create_list(:data_source_statistic, 2, data_source: source)
    stats << create(:total_statistic, data_source: source)
    stats
  end
  let!(:statistic_types) { statistics.map(&:type) }
  let!(:later_statistics) do
    statistic_types.map { |t| create(:data_source_statistic, type: t, data_source: source) }
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
      # Specify an order that is different to the inserted order and excludes
      # the total (since this always comes first)
      total_type = DataSourceStatistic::Types::TOTAL
      source.current_statistic_types = statistic_types.reject { |t| t == total_type }.shuffle
      source.save!
    end

    it 'returns the latest statistic for each of current_statistic_types' do
      expect(subject).to match_array(later_statistics)
    end

    it 'returns the most recent total statistic first' do
      total_stat = subject.first
      latest_total = later_statistics.find(&:total?)
      expect(total_stat).to eq(latest_total)
    end

    it 'returns the other statistics in the order of current_statistic_types' do
      other_stats = subject.drop(1)
      returned_types = other_stats.map(&:type)
      expect(source.current_statistic_types).to eq(returned_types)
    end

    it 'skips missing statistics' do
      # Add a type to current_statistic_types which we don't have a stat for
      source.current_statistic_types << 'missing'
      source.save!
      current_stats = source.current_statistics
      expect(current_stats.find { |s| s.type == 'missing' }).to be_nil
    end

    it 'skips missing totals' do
      source.statistics.select(&:total?).map(&:destroy)
      expect(source.current_statistics.find(&:total?)).to be_nil
    end
  end
end
