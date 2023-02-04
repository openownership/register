require 'rails_helper'

RSpec.describe EntitiesController do
  describe 'GET #show' do
    let(:entity) { create(:legal_entity) }

    before do
      Entity.import(force: true, refresh: true)
    end

    it 'sorts owned companies by started_date' do
      first_relationship = create(:relationship, source: entity, started_date: nil)
      second_relationship = create(:relationship, source: entity, started_date: '2019-08-28')
      third_relationship = create(:relationship, source: entity, started_date: '2019-08-29')

      expected_order = [
        third_relationship.id,
        second_relationship.id,
        first_relationship.id,
      ]

      get :show, params: { id: entity.id }

      # The actual results get paginated and decorated so aren't Relationship
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

    context 'when the entity has raw data provenance' do
      let(:data_source1) { create(:data_source, name: 'Data Source 1') }
      let(:data_source2) { create(:data_source, name: 'Data Source 2') }
      let(:import1) { create(:import, data_source: data_source1) }
      let(:import2) { create(:import, data_source: data_source2) }

      let!(:raw_provenances) do
        [
          create(:raw_data_provenance, entity_or_relationship: entity, import: import1),
          create(:raw_data_provenance, entity_or_relationship: entity, import: import2),
        ]
      end

      it 'sets a list of data source names' do
        get :show, params: { id: entity.id }
        expected = ['Data Source 1', 'Data Source 2']
        expect(assigns(:data_source_names)).to match_array(expected)
      end

      it 'sets the newest raw data record timestamp' do
        get :show, params: { id: entity.id }
        expected = raw_provenances.last.raw_data_records.last.updated_at
        expect(assigns(:newest_raw_record)).to be_within(1.second).of(expected)
      end

      it 'sets the total count of raw data records' do
        get :show, params: { id: entity.id }
        expect(assigns(:raw_record_count)).to eq(4)
      end
    end

    context 'when the entity has no raw data provenance' do
      it 'sets data source names to an empty list' do
        get :show, params: { id: entity.id }
        expect(assigns(:data_source_names)).to match_array([])
      end

      it "doesn't set the newest raw data record timestamp" do
        get :show, params: { id: entity.id }
        expect(assigns(:newest_raw_record)).to be_nil
      end

      it "doesn't set the total count of raw data records" do
        get :show, params: { id: entity.id }
        expect(assigns(:raw_record_count)).to be_nil
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

    context 'when the entity is a merged entity' do
      let!(:master_entity) { create(:natural_person) }
      let!(:merged_entity) do
        create(:natural_person, master_entity: master_entity)
      end
      it 'redirects to the master entity' do
        get :show, params: { id: merged_entity.id, format: :json }
        expect(response).to redirect_to(entity_path(master_entity, format: :json))
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

    it 'paginates raw data records, most recently updated first' do
      get :raw, params: { id: entity.id }
      expect(assigns(:raw_data_records)).to match_array(raw_data_records.last(10))
      get :raw, params: { id: entity.id, page: 2 }
      expect(assigns(:raw_data_records)).to match_array([raw_data_records.first])
    end

    it 'sets the global newest and oldest record dates for the entity' do
      expected_newest = Time.zone.now
      expected_oldest = 1.day.ago
      # Make one record newer than all the rest
      raw_data_records.first.timeless.update_attribute(:updated_at, expected_newest)
      # Make one record older than all the rest
      raw_data_records.last.timeless.update_attribute(:created_at, expected_oldest)
      get :raw, params: { id: entity.id }
      expect(assigns(:newest)).to be_within(1.second).of(expected_newest)
      expect(assigns(:oldest)).to be_within(1.second).of(expected_oldest)
    end

    it 'sets a list of data sources' do
      second_provenance = create(:raw_data_provenance, entity_or_relationship: entity)

      expected = [import.data_source, second_provenance.import.data_source]

      get :raw, params: { id: entity.id }
      expect(assigns(:data_sources)).to match_array(expected)
    end

    it "handles entities with no raw records" do
      entity_with_no_records = create(:legal_entity)

      get :raw, params: { id: entity_with_no_records.id }
      expect(assigns(:raw_data_records).to_a).to be_empty
      expect(assigns(:newest)).to be_nil
      expect(assigns(:oldest)).to be_nil
      expect(assigns(:data_sources)).to be_nil
    end
  end
end
