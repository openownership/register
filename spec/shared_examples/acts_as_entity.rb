require 'rails_helper'

RSpec.shared_examples_for "acts as entity" do
  describe '#legal_entity?' do
    subject { described_class.new(type: type).legal_entity? }

    context "when entity type is described_class::Types::LEGAL_ENTITY" do
      let(:type) { described_class::Types::LEGAL_ENTITY }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when entity type is not described_class::Types::LEGAL_ENTITY" do
      let(:type) { described_class::Types::NATURAL_PERSON }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe '#natural_person?' do
    subject { described_class.new(type: type).natural_person? }

    context "when entity type is described_class::Types::NATURAL_PERSON" do
      let(:type) { described_class::Types::NATURAL_PERSON }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when entity type is not described_class::Types::NATURAL_PERSON" do
      let(:type) { described_class::Types::LEGAL_ENTITY }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe '#country' do
    let(:entity) { described_class.new }
    subject { entity.country }

    context "when entity is a natural person" do
      before { entity.type = described_class::Types::NATURAL_PERSON }

      context "when entity does not have a nationality" do
        before { entity.nationality = nil }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has a nationality" do
        before { entity.nationality = "GB" }

        it "returns country of that nationality" do
          expect(subject).to eq(ISO3166::Country[:GB])
        end
      end
    end

    context "when entity is a legal entity" do
      before { entity.type = described_class::Types::LEGAL_ENTITY }

      context "when entity does not have a jurisdiction_code" do
        before { entity.jurisdiction_code = nil }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has an unknown jurisdiction_code" do
        before { entity.jurisdiction_code = "xx" }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has a jurisdiction_code" do
        before { entity.jurisdiction_code = "gb" }

        it "returns country of that jurisdiction" do
          expect(subject).to eq(ISO3166::Country[:GB])
        end
      end

      context "when entity has a jurisdiction_code with subdivision" do
        before { entity.jurisdiction_code = "gb_xx" }

        it "returns country of that jurisdiction" do
          expect(subject).to eq(ISO3166::Country[:GB])
        end
      end
    end
  end

  describe '#country_subdivision' do
    let(:entity) { described_class.new }
    subject { entity.country_subdivision }

    context "when entity is a natural person" do
      before { entity.type = described_class::Types::NATURAL_PERSON }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when entity is a legal entity" do
      before { entity.type = described_class::Types::LEGAL_ENTITY }

      context "when entity does not have a country" do
        before { entity.jurisdiction_code = nil }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity does not have a subdivision code" do
        before { entity.jurisdiction_code = "gb" }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has an unknown subdivision code" do
        before { entity.jurisdiction_code = "gb_xx" }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when entity has a known subdivision code" do
        before { entity.jurisdiction_code = "us_de" }

        it "returns subdivision" do
          expect(subject).to eq(ISO3166::Country[:US].subdivisions["DE"])
        end
      end
    end
  end
end
