require 'rails_helper'

RSpec.describe EntityResolver do
  let(:opencorporates_client) { instance_double('OpencorporatesClient') }

  let(:reconciliation_client) { instance_double('ReconciliationClient') }

  subject { EntityResolver.new(opencorporates_client: opencorporates_client, reconciliation_client: reconciliation_client) }

  describe '#resolve!' do
    context 'when the child company has an identifier' do
      context 'when the company is found with the opencorporates api' do
        before do
          @jurisdiction_code = 'gb'

          @company_number = '00902239'

          @company_name = 'BG INTERNATIONAL LIMITED'

          @identifier = '902239'

          @name = 'BG International Limited'

          response = {
            jurisdiction_code: @jurisdiction_code,
            company_number: @company_number,
            name: @company_name
          }

          expect(opencorporates_client).to receive(:get_company).with(@jurisdiction_code, @identifier).and_return(response)
        end

        it 'creates an entity with an identifier' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(Entity.count).to eq(1)

          entity = Entity.first

          expect(entity.identifiers.first._id).to be_a(Hash)
          expect(entity.identifiers.first._id.fetch('jurisdiction_code')).to eq(@jurisdiction_code)
          expect(entity.identifiers.first._id.fetch('company_number')).to eq(@company_number)
        end

        it 'uses the name from the api response' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          entity = Entity.first

          expect(entity.name).to eq(@company_name)
        end

        it 'returns the entity' do
          entity = subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(entity).to eq(Entity.first)
        end
      end

      context 'when the company is found with the opencorporates search api' do
        before do
          @jurisdiction_code = 'mm'

          @company_number = '203-2000-2001'

          @company_name = 'JADE MOUNTAIN COMPANY LIMITED'

          @identifier = '203 / 2000-2001'

          @name = 'Jade Mountain Gems'

          response = [
            {
              company: {
                name: @company_name,
                company_number: @company_number,
                jurisdiction_code: @jurisdiction_code
              }
            }
          ]

          expect(opencorporates_client).to receive(:get_company).with(@jurisdiction_code, @identifier).and_return(nil)
          expect(opencorporates_client).to receive(:search_companies).with(@jurisdiction_code, @identifier).and_return(response)
        end

        it 'creates an entity with an identifier' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(Entity.count).to eq(1)

          entity = Entity.first

          expect(entity.identifiers.first._id).to be_a(Hash)
          expect(entity.identifiers.first._id.fetch('jurisdiction_code')).to eq(@jurisdiction_code)
          expect(entity.identifiers.first._id.fetch('company_number')).to eq(@company_number)
        end

        it 'uses the name from the api response' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          entity = Entity.first

          expect(entity.name).to eq(@company_name)
        end

        it 'returns the entity' do
          entity = subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(entity).to eq(Entity.first)
        end
      end

      context 'when the company is not found' do
        before do
          @jurisdiction_code = 'mm'

          @identifier = '251/97'

          @name = 'PC Myanmar (Hong Kong) Limited'

          expect(opencorporates_client).to receive(:get_company).with(@jurisdiction_code, @identifier).and_return(nil)
          expect(opencorporates_client).to receive(:search_companies).with(@jurisdiction_code, @identifier).and_return([])
        end

        it 'returns nil' do
          entity = subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(entity).to be_nil
        end
      end
    end

    context 'when the child company does not have an identifier' do
      context 'when the company is found with the reconciliation api' do
        before do
          @jurisdiction_code = 'ca'

          @company_number = '2821281'

          @company_name = 'GOLDEN STAR RESOURCES LTD.'

          @identifier = nil

          @name = 'Golden Star Resources Ltd'

          response = {
            jurisdiction_code: @jurisdiction_code,
            company_number: @company_number,
            name: @company_name
          }

          expect(reconciliation_client).to receive(:reconcile).with(@jurisdiction_code, @name).and_return(response)
        end

        it 'creates an entity with an identifier' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(Entity.count).to eq(1)

          entity = Entity.first

          expect(entity.identifiers.first._id).to be_a(Hash)
          expect(entity.identifiers.first._id.fetch('jurisdiction_code')).to eq(@jurisdiction_code)
          expect(entity.identifiers.first._id.fetch('company_number')).to eq(@company_number)
        end

        it 'uses the name from the api response' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          entity = Entity.first

          expect(entity.name).to eq(@company_name)
        end

        it 'returns the entity' do
          entity = subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(entity).to eq(Entity.first)
        end
      end

      context 'when the company is not found' do
        before do
          @jurisdiction_code = 'id'

          @identifier = nil

          @name = 'PT Adaro Indonesia'

          expect(reconciliation_client).to receive(:reconcile).with(@jurisdiction_code, @name).and_return(nil)
        end

        it 'returns nil' do
          entity = subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(entity).to be_nil
        end
      end
    end
  end
end
