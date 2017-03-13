require 'rails_helper'

RSpec.describe Relationship do
  describe '#sample_date' do
    subject { Relationship.new(sample_date: sample_date).sample_date }

    context "when sample_date is nil" do
      let(:sample_date) { nil }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when sample_date is not nil" do
      let(:sample_date) { "2016-03-17" }

      it "returns an iso8601 date" do
        expect(subject).to eq(ISO8601::Date.new("2016-03-17"))
      end
    end
  end
end
