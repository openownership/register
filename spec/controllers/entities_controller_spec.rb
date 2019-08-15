require 'rails_helper'

RSpec.describe EntitiesController do
  describe 'GET #show' do
    let(:entity) { create(:legal_entity) }

    it 'sorts owned companies by ended_date and name' do
      first_company = create(:legal_entity, name: 'ABC')
      second_company = create(:legal_entity, name: 'ABC')
      third_company = create(:legal_entity, name: 'DEF')
      fourth_company = create(:legal_entity, name: 'DEF')

      first_relationship = create(:relationship, source: entity, target: first_company, ended_date: nil)
      second_relationship = create(:relationship, source: entity, target: second_company, ended_date: Time.zone.today.iso8601)
      third_relationship = create(:relationship, source: entity, target: third_company, ended_date: nil)
      fourth_relationship = create(:relationship, source: entity, target: fourth_company, ended_date: Time.zone.today.iso8601)

      expected_order = [
        first_relationship.id,
        third_relationship.id,
        second_relationship.id,
        fourth_relationship.id,
      ]

      get :show, params: { id: entity.id }

      # The actual results get paginated and decorated so aren't Relationships
      # instances, hence just matching ids
      actual_order = assigns('source_relationships').map(&:id)
      expect(actual_order).to eq(expected_order)
    end

    context 'when the entity is a merged entity' do
      let!(:master_entity) { create(:natural_person) }
      let!(:merged_entity) do
        create(:natural_person, master_entity: master_entity)
      end

      it 'redirects to the master entity' do
        get :show, params: { id: merged_entity.id }
        expect(response).to redirect_to(entity_path(master_entity))
      end
    end
  end

  describe 'GET #show, format: :json' do
    # See spec/system/entities for further tests of this, it doesn't really
    # warrant direct controller specs

    let!(:person) { create(:natural_person) }
    let!(:owned_companies) { create_list(:legal_entity, 11) }
    let!(:relationships) do
      owned_companies.map { |c| create(:relationship, source: person, target: c) }
    end

    it "doesn't paginate owned companies" do
      get :show, params: { id: person.id, format: :json }
      statements = JSON.parse(response.body)
      person_statements = statements.select { |s| s['statementType'] == 'personStatement' }
      entity_statements = statements.select { |s| s['statementType'] == 'entityStatement' }
      oc_statements = statements.select { |s| s['statementType'] == 'ownershipOrControlStatement' }

      expect(person_statements.length).to eq 1
      expect(entity_statements.length).to eq 11
      expect(oc_statements.length).to eq 11
    end
  end

  describe 'GET #tree' do
    context 'when the entity is a merged entity' do
      let!(:master_entity) { create(:natural_person) }
      let!(:merged_entity) do
        create(:natural_person, master_entity: master_entity)
      end

      it 'redirects to the master entity' do
        get :tree, params: { id: merged_entity.id }
        expect(response).to redirect_to(tree_entity_path(master_entity))
      end
    end
  end

  describe 'GET #graph' do
    context 'when the entity is a merged entity' do
      let!(:master_entity) { create(:natural_person) }
      let!(:merged_entity) do
        create(:natural_person, master_entity: master_entity)
      end

      it 'redirects to the master entity' do
        get :graph, params: { id: merged_entity.id }
        expect(response).to redirect_to(graph_entity_path(master_entity))
      end
    end
  end

  describe 'GET #opencorporates_additional_info' do
    let(:entity) { create(:legal_entity) }
    let(:oc_url) { "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/#{entity.jurisdiction_code}/#{entity.company_number}" }
    let(:oc_url_regex) { /#{Regexp.quote(oc_url)}/ }

    context 'when the OC api times out' do
      before do
        stub_request(:get, oc_url_regex).to_timeout
      end

      it 'rescues the timeout error' do
        get :opencorporates_additional_info, params: { id: entity.id }
        expect(response).to be_successful
      end

      it "doesn't set @opencorporates_company_hash" do
        get :opencorporates_additional_info, params: { id: entity.id }
        expect(assigns(:opencorporates_company_hash)).to be nil
      end

      it 'sets @oc_api_timed_out' do
        get :opencorporates_additional_info, params: { id: entity.id }
        expect(assigns(:oc_api_timed_out)).to be true
      end
    end
  end

  describe 'GET #raw' do
    let!(:entity) { create(:natural_person) }
    let!(:import) { create(:import) }
    let!(:raw_data_records) do
      create_list(:raw_data_record, 11, imports: [import])
    end
    let!(:raw_provenance) do
      create(
        :raw_data_provenance,
        entity_or_relationship: entity,
        raw_data_records: raw_data_records,
        import: import,
      )
    end

    context 'when the entity is a merged entity' do
      let!(:merged_entity) do
        create(:natural_person, master_entity: entity)
      end

      it 'redirects to the master entity' do
        get :raw, params: { id: merged_entity.id }
        expect(response).to redirect_to(raw_entity_path(entity))
      end
    end

    context 'when the entity has merged entities' do
      let!(:merged_entity) do
        create(:natural_person, master_entity: entity)
      end
      let(:merged_raw_record) { create(:raw_data_record, imports: [import]) }
      let!(:merged_raw_provenance) do
        create(
          :raw_data_provenance,
          entity_or_relationship: merged_entity,
          raw_data_records: [merged_raw_record],
          import: import,
        )
      end

      it 'includes the raw data records for the merged entities' do
        get :raw, params: { id: entity.id }
        expect(assigns(:raw_data_records)).to include(merged_raw_record)
      end
    end

    it 'paginates raw data records, most recently created first' do
      get :raw, params: { id: entity.id }
      expect(assigns(:raw_data_records)).to match_array(raw_data_records.last(10))
      get :raw, params: { id: entity.id, page: 2 }
      expect(assigns(:raw_data_records)).to match_array([raw_data_records.first])
    end
  end
end
