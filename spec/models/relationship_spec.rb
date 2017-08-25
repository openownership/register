require 'rails_helper'

RSpec.describe Relationship do
  subject do
    described_class.new(
      source_id: 1,
      target_id: 2,
      interests: [3, 4],
      sample_date: sample_date,
      provenance: provenance,
    )
  end

  let(:sample_date) { "2016-03-17" }
  let(:provenance) { Provenance.new }

  describe '#sample_date' do
    it "returns an iso8601 date" do
      expect(subject.sample_date).to eq(ISO8601::Date.new(sample_date))
    end

    context "when sample_date is nil" do
      let(:sample_date) { nil }

      it "returns nil" do
        expect(subject.sample_date).to be_nil
      end
    end
  end

  describe '#to_builder' do
    it 'returns a JSON representation' do
      expect(JSON.parse(subject.to_builder.target!)).to eq(
        'source_id' => '1',
        'target_id' => '2',
        'interests' => [3, 4],
        'sample_date' => [2016, 3, 17],
        'provenance' => {
          'source_url' => nil,
          'source_name' => nil,
          'retrieved_at' => nil,
          'imported_at' => nil,
        },
      )
    end
  end
end
