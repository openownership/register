require 'rails_helper'

RSpec.describe 'BODS Import' do
  include EntityHelpers
  include SearchHelpers

  let(:bods_api_url) { 'https://raw.githubusercontent.com/openownership/data-standard/da1f653e7f6ecd2af659fb63f2f082852be7597d/examples/1-single-direct.json' }

  let(:company) { Entity.find_by('identifiers.statement_id' => '1dc0e987-5c57-4a1c-b3ad-61353b66a9b7') }
  let(:person) { Entity.find_by('identifiers.statement_id' => '019a93f1-e470-42e9-957b-03559861b2e2') }
  let(:person_company_relationship) do
    Relationship.find_by(source: person, target: company)
  end

  let(:company_number) { '01234567' }

  before do
    # Mock the OpenCorporates api
    stub_oc_company_api_with_fixture('GB', company_number)
  end

  context 'when the statements are in order' do
    before do
      Entity.__elasticsearch__.create_index! force: true

      # Mock the github download we use for example data
      stub_request(:get, bods_api_url)
        .to_return(body: file_fixture('bods_single_direct_example.json').read)

      BodsImportTrigger.new(bods_api_url, ['GB-COH'], 100).call
      Sidekiq::Worker.drain_all

      # Force ES to index the documents right now (normally it waits 1 second)
      Entity.__elasticsearch__.refresh_index!
    end

    it 'imports the data and links it up correctly' do
      expect(company).not_to be_nil
      expect(person).not_to be_nil
      expect(person_company_relationship).not_to be_nil

      search_for 'Example'
      click_link 'EXAMPLE LTD'
      expect(page).to have_link(person.name)
      click_link "", href: relationship_href(person_company_relationship)
      expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
      expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"
    end
  end

  context 'when the statements are out of order' do
    before do
      Entity.__elasticsearch__.create_index! force: true

      # Mock the github download we use for example data
      stub_request(:get, bods_api_url)
        .to_return(body: file_fixture('bods_single_direct_example_out_of_order.json').read)

      allow(BodsChunkImportRetryWorker).to receive(:sidekiq_retry_in).and_return(0)

      BodsImportTrigger.new(bods_api_url, ['GB-COH'], 100).call
      Sidekiq::Worker.drain_all

      # Force ES to index the documents right now (normally it waits 1 second)
      Entity.__elasticsearch__.refresh_index!
    end

    it 'imports the data and links it up correctly' do
      expect(company).not_to be_nil
      expect(person).not_to be_nil
      expect(person_company_relationship).not_to be_nil

      search_for 'Example'
      click_link 'EXAMPLE LTD'
      expect(page).to have_link(person.name)
      click_link "", href: relationship_href(person_company_relationship)
      expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
      expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"
    end
  end

  context 'when the statements are in JSONL format' do
    before do
      Entity.__elasticsearch__.create_index! force: true

      # Mock the github download we use for example data
      records = Oj.load(file_fixture('bods_single_direct_example.json').read)
      jsonl_data = records.map { |r| Oj.dump(r, mode: :rails) }.join("\n") + "\n"
      stub_request(:get, bods_api_url).to_return(body: jsonl_data)

      BodsImportTrigger.new(bods_api_url, ['GB-COH'], 100, jsonl: true).call
      Sidekiq::Worker.drain_all

      # Force ES to index the documents right now (normally it waits 1 second)
      Entity.__elasticsearch__.refresh_index!
    end

    it 'imports the data and links it up correctly' do
      expect(company).not_to be_nil
      expect(person).not_to be_nil
      expect(person_company_relationship).not_to be_nil
    end
  end
end
