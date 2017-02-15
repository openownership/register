require 'rails_helper'

RSpec.describe Entity do
  describe '#upsert' do
    let(:identifier) do
      {
        _id: {
          jurisdiction_code: 'gb',
          company_number: '01234567'
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
