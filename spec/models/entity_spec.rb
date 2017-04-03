require 'rails_helper'

RSpec.describe Entity do
  it_behaves_like "acts as entity"

  describe '.find_or_unknown' do
    subject { Entity.find_or_unknown(id) }

    context "when id is id of a normal entity" do
      let(:id) { "1234" }

      it "finds the entity" do
        expect(Entity).to receive(:find).with(id).and_return(:entity)
        expect(subject).to eq(:entity)
      end
    end

    context "when id is id of an unknown persons entity" do
      let(:id) { "1234#{Entity::UNKNOWN_ID_MODIFIER}" }

      it "returns an unknown persons entity" do
        expect(subject).to be_a(UnknownPersonsEntity)
      end

      it "returns entity with same id" do
        expect(subject.id).to eq(id)
      end
    end
  end

  describe '#relationships_as_target' do
    let(:entity) { Entity.new }
    subject { entity.relationships_as_target }

    context "when entity is a Entity::Types::NATURAL_PERSON" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

      it "returns empty array" do
        expect(subject).to eq([])
      end
    end

    context "when entity is not a Entity::Types::NATURAL_PERSON" do
      before { entity.type = nil }

      context "when entity is target of some persisted relationships" do
        before do
          allow(entity).to receive(:_relationships_as_target).and_return([:relationship])
        end

        it "returns those relationships" do
          expect(subject).to eq([:relationship])
        end
      end

      context "when entity is target of no persisted relationships" do
        before do
          allow(entity).to receive(:_relationships_as_target).and_return([])
        end

        it "returns an array containing a relationship to an unknown persons entity" do
          expect(subject.count).to eq(1)
          expect(subject[0].source).to eq(UnknownPersonsEntity.new(id: "#{entity.id}#{Entity::UNKNOWN_ID_MODIFIER}"))
          expect(subject[0].target).to eq(entity)
        end
      end
    end
  end

  describe '#natural_person?' do
    subject { Entity.new(type: type).natural_person? }

    context "when entity type is Entity::Types::NATURAL_PERSON" do
      let(:type) { Entity::Types::NATURAL_PERSON }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "when entity type is not Entity::Types::NATURAL_PERSON" do
      let(:type) { Entity::Types::LEGAL_ENTITY }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe '#country' do
    let(:entity) { Entity.new }
    subject { entity.country }

    context "when entity is a natural person" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

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
      before { entity.type = Entity::Types::LEGAL_ENTITY }

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
    let(:entity) { Entity.new }
    subject { entity.country_subdivision }

    context "when entity is a natural person" do
      before { entity.type = Entity::Types::NATURAL_PERSON }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when entity is a legal entity" do
      before { entity.type = Entity::Types::LEGAL_ENTITY }

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

  describe '#country_code' do
    let(:entity) { Entity.new }

    subject { entity.country_code }

    context 'when the entity has a country' do
      before do
        allow(entity).to receive(:country).and_return(ISO3166::Country[:GB])
      end

      it 'returns the alpha2 code of the country' do
        expect(subject).to eq('GB')
      end
    end

    context 'when the entity does not have a country' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#upsert' do
    let(:jurisdiction_code) { 'gb' }

    let(:identifier) do
      {
        _id: {
          'jurisdiction_code' => jurisdiction_code,
          'company_number' => '01234567'
        }
      }
    end

    let(:name) { 'EXAMPLE LIMITED' }

    subject { Entity.new(identifiers: [Identifier.new(identifier)], name: name) }

    context 'when a document with the same identifier exists in the database' do
      before do
        @entity = Entity.create!(identifiers: [identifier], name: 'Example Limited')
      end

      it 'updates the fields of the existing document' do
        expect { subject.upsert }.to change { Entity.first.name }.to(name)
      end

      it 'updates the id of the subject to match the existing document' do
        expect { subject.upsert }.to change { subject.id }.to(@entity.id)
      end

      it 'does not create a new document' do
        expect { subject.upsert }.not_to change { Entity.count }
      end
    end

    context 'when no document with the same identifier exists in the database' do
      it 'creates a new document' do
        expect { subject.upsert }.to change { Entity.count }.from(0).to(1)
      end
    end

    it 'retries on duplicate key error exceptions' do
      # The findAndModify command is atomic but can potentially fail
      # due to unique index constraint violation, as documented here:
      # https://docs.mongodb.com/manual/reference/command/findAndModify/#upsert-and-unique-index

      collection = subject.collection

      allow(subject).to receive(:collection).and_return(collection)

      error = Mongo::Error::OperationFailure.new('E11000 duplicate key error collection: ...')

      expect(collection).to receive(:find_one_and_update).and_raise(error)
      expect(collection).to receive(:find_one_and_update).and_call_original

      subject.upsert
    end
  end
end
