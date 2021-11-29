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

  describe 'validating types' do
    it 'only allows types from the allowed TYPES list' do
      expect(source).to be_valid
      source.types << 'badType'
      source.validate
      expect(source).not_to be_valid
      expect(source.errors[:types]).not_to be_blank
    end

    it 'skips data sources with no types' do
      source.types = []
      expect(source).to be_valid
    end
  end

  describe '.all_for_entity' do
    let(:entity) { create(:legal_entity) }
    let!(:provenances) do
      create_list(:raw_data_provenance, 3, entity_or_relationship: entity)
    end
    let(:data_sources) { provenances.map { |p| p.import.data_source } }

    it 'returns all the data sources the entity is connected to via raw data' do
      expect(DataSource.all_for_entity(entity)).to match_array(data_sources)
    end

    it "doesn't return duplicate data sources" do
      create(:raw_data_provenance, entity_or_relationship: entity, import: provenances.first.import)
      expect(DataSource.all_for_entity(entity)).to match_array(data_sources)
    end
  end

  describe '#statistics_by_type' do
    subject { source.statistics_by_type }

    it 'returns a Hash with Arrays of stats keyed by type', :aggregate_failures do
      expect(subject).to be_a Hash
      expect(subject.keys.length).to eq statistic_types.length
      statistic_types.each do |t|
        expect(subject.keys).to include(t)
        expect(subject[t]).to be_a Array
        expect(subject[t].length).to eq(2)
      end
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

  describe '#most_recent_import' do
    let!(:data_source) { create(:data_source) }

    context 'when there are imports connected to the data source' do
      let!(:imports) do
        (0..2).map do |i|
          import = create(:import, data_source: data_source)
          import.timeless.update_attribute(:created_at, i.days.ago)
          import
        end
      end

      it 'returns the most recently created one' do
        expect(data_source.most_recent_import).to eq(imports[0])
      end
    end

    context 'when there are no imports connected to the data source' do
      it 'returns nil' do
        expect(data_source.most_recent_import).to be_nil
      end
    end
  end
end
