require 'rails_helper'

RSpec.describe EntityHelper do
  let(:entity) { Entity.new }

  describe '#entity_name_or_tooltip' do
    subject { helper.entity_name_or_tooltip(entity, :top) }

    context "when entity is a normal entity" do
      before { entity.name = "name" }

      it 'returns the entity name' do
        expect(subject).to eq("name")
      end
    end

    context "when entity is a unknown persons entity" do
      let(:entity) { UnknownPersonsEntity.new }

      it "returns a tooltip" do
        expect(helper).to receive(:glossary_tooltip).with(
          content_tag(:span, "unknown persons", class: "unknown"),
          :unknown_persons,
          anything,
        ).and_return(:tooltip)

        expect(subject).to eq(:tooltip)
      end
    end
  end

  describe '#entity_link' do
    subject do
      helper.entity_link(entity) do
        "label"
      end
    end

    context "when entity is a normal entity" do
      before { allow(entity).to receive(:persisted?).and_return(true) }

      it 'returns a link to entity' do
        expect(subject).to eq(content_tag(:a, "label", href: entity_path(entity)))
      end
    end

    context "when entity is a circular ownership entity" do
      let(:entity) { CircularOwnershipEntity.new }

      it 'returns just the label' do
        expect(subject).to eq("label")
      end
    end

    context "when entity is a unknown persons entity" do
      let(:entity) { UnknownPersonsEntity.new }

      it 'returns just the label' do
        expect(subject).to eq("label")
      end
    end
  end

  describe '#entity_jurisdiction' do
    subject { helper.entity_jurisdiction(entity, short: short) }
    let(:short) { false }

    context 'when the entity has a country' do
      context 'when the entity does not have a subdivision' do
        before { allow(entity).to receive(:country).and_return(ISO3166::Country[:GB]) }
        before { allow(entity).to receive(:country_subdivision).and_return(nil) }

        it 'returns the name of the country' do
          expect(subject).to eq('United Kingdom of Great Britain and Northern Ireland')
        end

        context "when short requested" do
          let(:short) { true }

          it "returns the shorter name of the country" do
            expect(subject).to eq('United Kingdom')
          end
        end
      end

      context 'when the jurisdiction matches a subdivision of a country' do
        before { allow(entity).to receive(:country).and_return(ISO3166::Country[:US]) }
        before { allow(entity).to receive(:country_subdivision).and_return(ISO3166::Country[:US].subdivisions["DE"]) }

        it 'returns the name of the subdivision' do
          expect(subject).to eq('Delaware (United States of America)')
        end

        context "when short requested" do
          let(:short) { true }

          it "returns the shorter name of the country" do
            expect(subject).to eq('Delaware (US)')
          end
        end
      end
    end

    context 'when the entity does not have a country' do
      before { allow(entity).to receive(:country).and_return(nil) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#entity_attributes_snippet' do
    subject { helper.entity_attributes_snippet(entity) }

    context "when entity is a natural person" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

      context "when entity doesn't have attributes" do
        before do
          allow(helper).to receive(:date_of_birth).with(entity).and_return(nil)
          allow(entity).to receive(:country).and_return(nil)
        end

        it "returns nothing" do
          expect(subject).to be_blank
        end
      end

      context "when entity has attributes" do
        before do
          allow(helper).to receive(:date_of_birth).with(entity).and_return("February 1980")
          allow(entity).to receive(:country).and_return(ISO3166::Country[:GB])
        end

        it "returns formatted string" do
          expect(subject).to eq("British (Born February 1980)")
        end
      end
    end

    context "when entity is a legal entity" do
      before { entity.type = Entity::Types::LEGAL_ENTITY }

      context "when entity doesn't have attributes" do
        before do
          allow(helper).to receive(:entity_jurisdiction).with(entity, short: true).and_return(nil)
          entity.incorporation_date = entity.dissolution_date = nil
        end

        it "returns nothing" do
          expect(subject).to be_blank
        end
      end

      context "when entity has attributes" do
        before do
          allow(helper).to receive(:entity_jurisdiction).with(entity, short: true).and_return("United Kingdom")
          entity.incorporation_date = entity.dissolution_date = Date.new(1980, 2, 27)
        end

        it "returns formatted string" do
          expect(subject).to eq("United Kingdom (1980-02-27 – 1980-02-27)")
        end
      end
    end
  end

  describe '#date_of_birth' do
    let(:entity) { Entity.new(dob: dob) }

    subject { helper.date_of_birth(entity) }

    {
      nil => nil,
      ISO8601::Date.new('1980') => '1980',
      ISO8601::Date.new('1980-02') => 'February 1980',
      ISO8601::Date.new('1980-02-27') => 'February 1980',
    }.each do |date, expected|
      context "when entity dob is #{date ? date.mongoize : date.inspect}" do
        let(:dob) { date }

        it "returns #{expected.inspect}" do
          expect(subject).to eq(expected)
        end
      end
    end
  end
end
