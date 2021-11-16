require 'rails_helper'

RSpec.describe 'DK Import' do
  include EntityHelpers
  include SearchHelpers

  let(:data_source) { create(:dk_data_source) }

  let(:dk_api_url) { 'http://distribution.virk.dk/cvr-permanent/deltager/_search?scroll=10m' }
  let(:dk_api_scroll_url) { "http://distribution.virk.dk/_search/scroll" }

  let(:oc_api_url) { 'https://api.opencorporates.com/v0.4.6/companies/dk' }
  let(:oc_query) { 'api_token=&sparse=true' }

  # Expected entities and relationships
  let(:person1) { Entity.find_by(name: 'Danish Person 1') }
  let(:person1_companies) do
    companies = []
    [
      "Renamed Danish Company 1",
      "Danish Company 2",
    ].each do |name|
      companies << Entity.find_by(name: name)
    end
    companies
  end

  let(:person2) { Entity.find_by(name: 'Danish Person 2') }
  let(:person2_company) { Entity.find_by(name: 'Danish Company 3') }

  let(:company_numbers) do
    %i[
      1234567
      89101112
      13141516
    ]
  end

  let(:api_response) { file_fixture('dk_bo_api_response.json').read }
  let(:end_api_response) { file_fixture('dk_bo_api_response_end.json').read }

  let(:person1_raw_data) do
    file_fixture('dk_bo_datum_with_real_owners_complex.json').read
  end
  let(:person2_raw_data) do
    file_fixture('dk_bo_datum_with_real_owners_simple.json').read
  end

  let(:person1_raw_record) do
    etag = RawDataRecord.etag("2015-01-02T00:00:00.000+01:00_1")
    RawDataRecord.find_by(etag: etag)
  end

  let(:person2_raw_record) do
    etag = RawDataRecord.etag("2015-01-01T00:00:00.000+02:00_2")
    RawDataRecord.find_by(etag: etag)
  end

  before do
    Entity.__elasticsearch__.create_index! force: true

    stub_request(:get, dk_api_url)
      .to_return(
        body: api_response,
        headers: { 'Content-Type': 'application/json' },
      )

    stub_request(:get, dk_api_scroll_url)
      .to_return(
        body: end_api_response,
        headers: { 'Content-Type': 'application/json' },
      )

    company_numbers.each do |company_number|
      stub_oc_company_api_with_fixture('dk', company_number)
    end

    DkImportTrigger.new.call(data_source, 1)
    Sidekiq::Worker.drain_all

    # Force ES to index the documents right now (normally it waits 1 second)
    Entity.__elasticsearch__.refresh_index!
  end

  it 'imports the data and links it up correctly' do
    expect(person1).not_to be_nil
    expect(person2).not_to be_nil
    person1_companies.each { |c| expect(c).not_to be_nil }
    expect(person2_company).not_to be_nil
    person1_companies.each do |company|
      relationship = Relationship.find_by(source: person1, target: company)
      expect(relationship).not_to be_nil
    end
    person2_relationship = Relationship.find_by(source: person2, target: person2_company)
    expect(person2_relationship).not_to be_nil
    expect(person1_raw_record).not_to be_nil
    expect(person2_raw_record).not_to be_nil

    search_for 'Danish Person 1'
    click_link 'Danish Person 1'
    person1_companies.each { |c| expect(page).to have_link(c.name) }
    first_relationship = Relationship.find_by(source: person1, target: person1_companies.first)
    click_link "", href: relationship_href(first_relationship)
    expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
    expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"

    visit raw_entity_path(person1)
    expect(page).to have_text JSON.pretty_generate(JSON.parse(person1_raw_data))

    visit raw_entity_path(person1_companies.first)
    expect(page).to have_text JSON.pretty_generate(JSON.parse(person1_raw_data))

    search_for 'Danish Person 2'
    click_link 'Danish Person 2'
    click_link "", href: relationship_href(person2_relationship)
    expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
    expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"

    visit raw_entity_path(person2)
    expect(page).to have_text JSON.pretty_generate(JSON.parse(person2_raw_data))

    visit raw_entity_path(person2_company)
    expect(page).to have_text JSON.pretty_generate(JSON.parse(person2_raw_data))
  end
end
