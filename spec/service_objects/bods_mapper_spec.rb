require 'rails_helper'

RSpec.describe BodsMapper do
  describe "#statement_id" do
    context "for Entities" do
      it "returns a stable digest of their id and a namespace"
    end

    context "for Relationships" do
      it "returns a stable digest of their id"
    end

    it "raises an error for other classes"
  end

  describe "#entity_statement" do
    it "gives the statement an id"
    it 'sets statementType to entityStatement'
    it 'maps entityType to registeredEntity'
    it 'sets statementDate to nil'
    it 'sets the entity name'

    describe 'mapping identifiers' do
      context 'GB PSC' do
        context 'companies' do
          it 'sets the scheme to GB-COH and uses the company number for id'
        end
        context 'people' do
          it 'returns nil'
        end
      end

      context 'Denmark CVR' do
        context 'companies' do
          it 'sets the scheme to DK-CVR and uses the company number for id'
        end
        context 'people' do
          it 'sets the scheme to MISC-Denmark CVR and uses the beneficial owner id'
        end
      end

      context 'Slovakia PSP' do
        context 'companies' do
          it 'sets the scheme to SK-ORSR and uses the company number for id'
        end
        context 'people' do
          it 'sets the scheme to MISC-Slovakia PSP Register and uses the beneficial owner id'
        end
      end

      context 'Ukraine EDR' do
        context 'companies' do
          it 'sets the scheme to UA-EDR and uses the company number for id'
        end
        context 'people' do
          it 'returns nil'
        end
      end

      context 'EITI' do
        it 'returns nil for both companies and people'
      end

      context 'other sources' do
        it 'returns nil for both companies and people'
      end
    end

    describe 'mapping addresses' do
      it "maps to nil if there's no address"
      it 'maps to a registered address'

      describe 'setting country' do
        it "maps to nil if the entity has no country_code"
        it "maps to the entity's country_code if it exists"
      end
    end

    it 'maps foundingDate to ISO8601 formatted incorporation_date if it exists'
    it 'maps dissolutionDate to ISO8601 formatted dissolution_date if it exists'
  end

  describe "#person_statement" do
    it "gives the statement an id"
    it 'sets statementDate to nil'
    it 'sets statementType to personStatement'
    it 'sets personType to knownPerson'

    describe 'mapping nationalities' do
      it "maps to nil if there's no nationality"
      it "maps to nil if there's a nationality but it's not a known country"
      it "maps to a country name and two-digit code if there's a nationality"
    end

    describe 'mapping addresses' do
      it "maps to nil if there's no address"

      describe "setting country" do
        context "when the country_of_residence looks like a country code" do
          it 'maps to nil if its not a known country code'
          it 'maps to the country code if its a known country code'
        end
        it 'maps to the ISO3166 code if the country_of_residence can be found as a name'
        it 'maps to the ISO3166 code if the country_of_residence can be found as a 3 digit code'
      end
    end
  end

  describe "#ownership_or_control_statement" do
    describe 'setting statementDate' do
      it "maps to the sample_date if it's set"
      it 'maps to nil if the sample_date is not set'
    end

    it "maps the subject to the relationship's target's id"
    it "maps the interestedParty to the relationship's source's id"
    it "maps the interestedParty to the relationship's source's id"

    describe 'mapping interests' do
      context 'when the interests are a Hash' do
        it 'maps the type from the interest'
        it "maps values to 'exact' if min == max"
        it "maps values to min/max separately if min != max"
        # TODO: BODS imported data will break this hard-coding!
        it "sets exclusiveMinimum and Maximum to false"
      end

      context 'when the interests are a string' do
        context '25-50% shareholdings'
        context '50-75% shareholdings'
        context '75-100% shareholdings'
        context '25-50% voting rights'
        context '50-75% voting rights'
        context '75-100% voting rights'
        context 'rights to appoint directors'
        context 'rights to share surplus'
        context 'significant influence or control'
        context 'other interest strings'
      end
    end
  end
end
