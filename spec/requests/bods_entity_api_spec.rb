require 'rails_helper'

RSpec.describe 'BODS Entity API', type: :request do
  def json_response
    JSON.parse(response.body)
  end

  describe 'GET /entities/:id.json' do
    context 'for an entity with no relationships' do
      let!(:entity) { create :legal_entity }

      it 'returns an empty JSON list' do
        get entity_path(entity, format: :json)
        expect(response).to have_http_status(200)
        expect(json_response).to eq []
      end
    end

    context 'for an entity that is part of a chain of relationships' do
      let(:legal_entity_1) do
        create(
          :legal_entity,
          identifiers: [
            { jurisdiction_code: 'gb', company_number: '12345' },
            { document_id: 'GB PSC Snapshot', company_number: '12345' },
          ],
          name: 'Company A',
          address: '123 not hidden street',
          jurisdiction_code: 'gb',
          company_number: '12345',
          incorporation_date: 2.months.ago,
          dissolution_date: 1.month.ago,
        )
      end

      let(:legal_entity_2) do
        create(
          :legal_entity,
          identifiers: [
            { jurisdiction_code: 'dk', company_number: '67890' },
            { document_id: 'Denmark CVR', company_number: '67890' },
            { document_id: 'GB PSC Snapshot', link: 'fooo', company_number: '67890' },
          ],
          name: 'Company B',
          address: '1234 hidden street',
          jurisdiction_code: 'dk',
          company_number: '67890',
          incorporation_date: 2.months.ago,
          dissolution_date: 1.month.ago,
        )
      end

      let(:natural_person) do
        create(
          :natural_person,
          identifiers: [
            { document_id: 'Denmark CVR', beneficial_owner_id: 'P123456' },
          ],
          name: 'Miss Yander Stud',
          address: '25 road street',
          dob: 50.years.ago.to_date.to_s,
          country_of_residence: 'gb',
          nationality: 'gb',
        )
      end

      let!(:relationships) do
        [
          create(
            :relationship,
            source: legal_entity_2,
            target: legal_entity_1,
            interests: [
              'ownership-of-shares-25-to-50-percent',
              'voting-rights-50-to-75-percent',
              'significant-influence-or-control',
              'blah nlah nlah',
            ],
            provenance: create(:provenance, source_name: 'UK PSC Register'),
          ),
          create(
            :relationship,
            source: natural_person,
            target: legal_entity_2,
            interests: [
              {
                type: 'shareholding',
                share_min: 100,
                share_max: 100,
              },
              {
                type: 'voting-rights',
                share_min: 25,
                share_max: 49.99,
              },
              'significant-influence-or-control',
            ],
            provenance: create(:provenance, source_name: 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])'),
          ),
        ]
      end

      it 'should return a list of BODS statements for the whole chain' do
        get entity_path(legal_entity_1, format: :json)
        expect(response).to have_http_status(200)
        expect(json_response.size).to eq 5
        expect(response).to be_valid_bods
      end
    end
  end
end
