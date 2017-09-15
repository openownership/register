require 'rails_helper'

RSpec.describe ModelExport do
  subject { described_class.new(model) }

  let(:record) { double }
  let(:another_record) { double }
  let(:records) { [record, another_record] }
  let(:exported_data) { 'exported data' }

  before do
    allow(record).to receive_message_chain(:to_builder, :target!)
      .and_return exported_data
    allow(another_record).to receive_message_chain(:to_builder, :target!)
      .and_return exported_data
  end

  describe '#each' do
    it 'calls to_builder.target! on each record' do
      expect(ModelExport.new(records).to_a).to eq [exported_data, exported_data]
    end
  end

  describe '#name' do
    it 'returns the model name' do
      expect(ModelExport.new(Entity).name).to eq 'entities'
    end
  end
end
