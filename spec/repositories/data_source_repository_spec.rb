require 'rails_helper'

RSpec.describe DataSourceRepository do
  subject { described_class.new }

  let(:data_source) { create(:data_source) }

  describe '#all' do
    it 'returns all datasources' do
      expect(subject.all).to eq([data_source])
    end
  end

  describe '#find' do
    context 'when record exists' do
      let(:id) { data_source.id }
    end

    context 'when record does not exist' do
      let(:id) { 'abc' }

      it 'raises error' do
        expect { subject.find(id) }.to raise_error(Mongoid::Errors::DocumentNotFound)
      end
    end
  end

  describe '#where_overview_present' do
    
  end

  describe '#data_source_names_for_entity' do
    let(:entity) { create(:entity) }

    it 'returns all datasources' do
      expect(subject.all).to eq([data_source])
    end
  end

  describe '#data_sources_for_entity' do
    it 'returns all datasources' do
      expect(subject.all).to eq([data_source])
    end
  end
end
