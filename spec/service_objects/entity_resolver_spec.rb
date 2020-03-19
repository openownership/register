require 'rails_helper'

RSpec.describe EntityResolver do
  let(:opencorporates_client) { instance_double('OpencorporatesClient') }
  let(:reconciliation_client) { instance_double('ReconciliationClient') }
  let(:entity_resolver) do
    EntityResolver.new(
      opencorporates_client: opencorporates_client,
      reconciliation_client: reconciliation_client,
    )
  end
  let(:name) { 'EXAMPLE COMPANY LIMITED' }
  let(:entity) do
    Entity.new(
      jurisdiction_code: 'gb',
      company_number: @company_number,
      name: name,
    )
  end
  let(:get_response) do
    {
      jurisdiction_code: 'gb',
      company_number: '01234567',
      name: 'EXAMPLE COMPANY LIMITED',
      registered_address_in_full: "123 Main Street, Example Town, Exampleshire, EX4 2MP",
      incorporation_date: "2015-01-01",
      dissolution_date: "2015-01-02",
      company_type: "Limited company",
      updated_at: "2015-01-02T00:00:00+00:00",
    }
  end
  let(:search_response) do
    [
      {
        company: get_response,
      },
    ]
  end
  let(:reconcile_response) do
    {
      jurisdiction_code: 'gb',
      company_number: '01234567',
      name: 'EXAMPLE COMPANY LIMITED',
    }
  end

  subject do
    entity_resolver.resolve!(entity)
  end

  describe '#resolve!' do
    context 'when the company has no jurisdiction_code' do
      before do
        entity.jurisdiction_code = nil
      end

      it 'does nothing' do
        original_entity = entity.clone

        subject

        expect(entity.attributes.except('_id')).to eq(original_entity.attributes.except('_id'))
      end
    end

    context 'when the company has a company_number' do
      before do
        @company_number = '1234567'
      end

      shared_examples "it uses data found in the opencorporates api" do
        it 'adds an identifier to the entity' do
          subject

          expect(entity.identifiers).to include(
            'jurisdiction_code' => 'gb',
            'company_number' => '01234567',
          )
        end

        it 'uses the information from the api response' do
          subject

          expect(entity.name).to eq('EXAMPLE COMPANY LIMITED')
          expect(entity.address).to eq("123 Main Street, Example Town, Exampleshire, EX4 2MP")
          expect(entity.jurisdiction_code).to eq('gb')
          expect(entity.company_number).to eq('01234567')
          expect(entity.incorporation_date).to eq(Date.new(2015, 1, 1))
          expect(entity.dissolution_date).to eq(Date.new(2015, 1, 2))
          expect(entity.company_type).to eq("Limited company")
          expect(entity.oc_updated_at).to eq Time.new(2015, 1, 2, 0, 0, 0, "+00:00")
        end
      end

      context 'when the company is found with the opencorporates api' do
        before do
          allow(opencorporates_client)
            .to(receive(:get_company))
            .with('gb', @company_number)
            .and_return(get_response)
        end

        include_examples "it uses data found in the opencorporates api"

        it 'sets last_resolved_at' do
          subject

          expect(entity.last_resolved_at).to be_within(1.second).of(Time.zone.now)
        end
      end

      context 'when the company is not found with the opencorporates api' do
        before do
          allow(opencorporates_client)
            .to(receive(:get_company))
            .with('gb', @company_number)
            .and_return(nil)
        end

        context 'when the company is found with the opencorporates search api' do
          before do
            allow(opencorporates_client)
              .to(receive(:search_companies))
              .with('gb', @company_number)
              .and_return(search_response)
          end

          include_examples "it uses data found in the opencorporates api"

          it 'sets last_resolved_at' do
            subject

            expect(entity.last_resolved_at).to be_within(1.second).of(Time.zone.now)
          end
        end

        context 'when the company is not found with the opencorporates search api' do
          before do
            allow(opencorporates_client)
              .to(receive(:search_companies))
              .with('gb', @company_number)
              .and_return([])
          end

          it 'does nothing' do
            original_entity = entity.clone

            subject

            expect(entity.attributes.except('_id')).to eq(original_entity.attributes.except('_id'))
          end
        end
      end
    end

    context 'when the company does not have a company_number but does have a name' do
      before do
        @company_number = nil
      end

      context 'when the company is found with the reconciliation api' do
        before do
          allow(reconciliation_client)
            .to(receive(:reconcile))
            .with('gb', name)
            .and_return(reconcile_response)
        end

        it 'retries resolving with returned details' do
          allow(entity_resolver).to receive(:resolve!).and_call_original
          expect(entity_resolver).to receive(:resolve!).with(having_attributes(
            jurisdiction_code: 'gb',
            company_number: '01234567',
            name: 'EXAMPLE COMPANY LIMITED',
          )).and_return(nil)

          subject
        end
      end

      context 'when the company is not found' do
        before do
          allow(reconciliation_client).to receive(:reconcile).with('gb', name).and_return(nil)
        end

        it 'does nothing' do
          original_entity = entity.clone

          subject

          expect(entity.attributes.except('_id')).to eq(original_entity.attributes.except('_id'))
        end
      end
    end
  end

  describe 'logging changes during resolution' do
    let(:updated_company_number) { '89101112' }
    let(:expected_msg) do
      "[EntityResolver] Resolution with OpenCorporates changed the " \
      "company number of Entity with identifiers: #{entity.identifiers}. " \
      "Old number: #{@company_number}. " \
      "New number: #{updated_company_number}. " \
      "Old name: #{name}. New name: #{name}."
    end

    shared_examples "it logs the changes" do
      it 'logs the changes' do
        expect(Rails.logger).to receive(:info).with(expected_msg)
        subject
      end
    end

    shared_examples "it doesn't log any changes" do
      it "doesn't log any changes" do
        expect(Rails.logger).not_to receive(:info)
        subject
      end
    end

    before do
      @company_number = '01234567'
    end

    context "when company_number changes" do
      context "via the search api" do
        let(:updated_response) do
          updated_response = search_response
          updated_response.first[:company][:company_number] = updated_company_number
          updated_response
        end

        before do
          allow(opencorporates_client)
            .to(receive(:get_company))
            .with('gb', @company_number)
            .and_return(nil)
          allow(opencorporates_client)
            .to(receive(:search_companies))
            .with('gb', @company_number)
            .and_return(updated_response)
        end

        include_examples "it logs the changes"
      end

      context "via name reconciliation" do
        let(:updated_response) do
          updated_response = reconcile_response
          updated_response[:company_number] = updated_company_number
          updated_response
        end

        before do
          @company_number = nil
          allow(reconciliation_client)
            .to(receive(:reconcile))
            .with('gb', name)
            .and_return(updated_response)
          # First call we're testing
          allow(entity_resolver).to(receive(:resolve!)).and_call_original
          # Second recursive call we don't care about
          expect(entity_resolver)
            .to(receive(:resolve!))
            .with(having_attributes(company_number: updated_company_number))
            .and_return(nil)
        end

        include_examples "it logs the changes"
      end
    end

    context "when the company number doesn't change" do
      context "via the search api" do
        before do
          allow(opencorporates_client)
            .to(receive(:get_company))
            .with('gb', @company_number)
            .and_return(nil)
          allow(opencorporates_client)
            .to(receive(:search_companies))
            .with('gb', @company_number)
            .and_return(search_response)
        end

        include_examples "it doesn't log any changes"
      end
    end

    context "when the company is not found" do
      before do
        allow(opencorporates_client)
          .to(receive(:get_company))
          .with('gb', @company_number)
          .and_return(nil)
        allow(opencorporates_client)
          .to(receive(:search_companies))
          .with('gb', @company_number)
          .and_return([])
        allow(reconciliation_client)
          .to(receive(:reconcile))
          .with('gb', name)
          .and_return(nil)
      end

      include_examples "it doesn't log any changes"
    end
  end
end
