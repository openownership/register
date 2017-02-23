require 'rails_helper'

RSpec.describe EntityHelper do
  let(:entity) { Entity.new }

  describe '#entity_country_flag' do
    subject { helper.entity_country_flag(entity) }

    context 'when the entity has a country' do
      before { allow(entity).to receive(:country).and_return(ISO3166::Country[:GB]) }

      it 'returns the corresponding country flag image' do
        expect(subject).to match(/^<img /)
        expect(subject).to match(%r{src="/assets/GB-.+\.svg"})
        expect(subject).to match(/alt="United Kingdom/)
      end
    end

    context 'when the entity does not have a country' do
      before { allow(entity).to receive(:country).and_return(nil) }

      it 'returns nil' do
        expect(subject).to be_nil
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
    subject { helper.date_of_birth(entity) }

    {
      [1980, nil, nil] => "1980",
      [nil,  2,   nil] => "",
      [nil,  nil, 27] => "",
      [1980, 2,   nil] => "February 1980",
      [1980, nil, 27] => "1980",
      [nil,  2,   27] => "27 February",
      [1980, 2,   27] => "27 February 1980"
    }.each do |(year, month, day), expected|
      context "when entity data of birth data is #{[year, month, day]}" do
        before do
          entity.dob_year = year
          entity.dob_month = month
          entity.dob_day = day
        end

        it "returns #{expected}" do
          expect(subject).to eq(expected)
        end
      end
    end
  end
end
