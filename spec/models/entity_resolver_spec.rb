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
            name: @company_name,
            registered_address_in_full: "123 Main Street, Example Town, Exampleshire, EX4 2MP",
            incorporation_date: "1980-02-27",
            dissolution_date: "1980-02-27",
            company_type: "Limited company",
          }

          expect(opencorporates_client).to receive(:get_company).with(@jurisdiction_code, @identifier).and_return(response)
        end

        it 'creates an entity with an identifier' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(Entity.count).to eq(1)

          entity = Entity.first

          expect(entity.identifiers.first).to eq(
            'jurisdiction_code' => @jurisdiction_code,
            'company_number' => @company_number,
          )
        end

        it 'sets the type to Entity::Types::LEGAL_ENTITY' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          entity = Entity.first

          expect(entity.type).to eq(Entity::Types::LEGAL_ENTITY)
        end

        it 'uses the information from the api response' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          entity = Entity.first

          expect(entity.name).to eq(@company_name)
          expect(entity.address).to eq("123 Main Street, Example Town, Exampleshire, EX4 2MP")
          expect(entity.jurisdiction_code).to eq(@jurisdiction_code)
          expect(entity.company_number).to eq(@company_number)
          expect(entity.incorporation_date).to eq(Date.new(1980, 2, 27))
          expect(entity.dissolution_date).to eq(Date.new(1980, 2, 27))
          expect(entity.company_type).to eq("Limited company")
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
                jurisdiction_code: @jurisdiction_code,
                registered_address_in_full: "123 Main Street, Example Town, Exampleshire, EX4 2MP",
                incorporation_date: "1980-02-27",
                dissolution_date: "1980-02-27",
                company_type: "Limited company",
              },
            },
          ]

          expect(opencorporates_client).to receive(:get_company).with(@jurisdiction_code, @identifier).and_return(nil)
          expect(opencorporates_client).to receive(:search_companies).with(@jurisdiction_code, @identifier).and_return(response)
        end

        it 'creates an entity with an identifier' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          expect(Entity.count).to eq(1)

          entity = Entity.first

          expect(entity.identifiers.first).to eq(
            'jurisdiction_code' => @jurisdiction_code,
            'company_number' => @company_number,
          )
        end

        it 'uses the information from the api response' do
          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)

          entity = Entity.first

          expect(entity.name).to eq(@company_name)
          expect(entity.address).to eq("123 Main Street, Example Town, Exampleshire, EX4 2MP")
          expect(entity.jurisdiction_code).to eq(@jurisdiction_code)
          expect(entity.company_number).to eq(@company_number)
          expect(entity.incorporation_date).to eq(Date.new(1980, 2, 27))
          expect(entity.dissolution_date).to eq(Date.new(1980, 2, 27))
          expect(entity.company_type).to eq("Limited company")
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
            name: @company_name,
          }

          expect(reconciliation_client).to receive(:reconcile).with(@jurisdiction_code, @name).and_return(response)
        end

        it 'retries resolving with returned details' do
          allow(subject).to receive(:resolve!).and_call_original
          expect(subject).to receive(:resolve!).with(jurisdiction_code: @jurisdiction_code, identifier: @company_number, name: @company_name).and_return(nil)

          subject.resolve!(jurisdiction_code: @jurisdiction_code, identifier: @identifier, name: @name)
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
