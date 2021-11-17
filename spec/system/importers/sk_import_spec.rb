require 'rails_helper'

RSpec.describe 'SK Import' do
  include EntityHelpers
  include SearchHelpers

  let(:data_source) { create(:sk_data_source) }

  let(:sk_api_url) { 'https://rpvs.gov.sk/OpenData/Partneri' }
  let(:sk_query) { '$expand=PartneriVerejnehoSektora($expand=*),KonecniUzivateliaVyhod($expand=*)' }

  let(:oc_api_url) { 'https://api.opencorporates.com/v0.4.6/companies/sk' }
  let(:oc_query) { 'api_token=&sparse=true' }

  let(:google_geocode_api_url) { "https://maps.googleapis.com/maps/api/geocode/json?address=" }
  let(:google_geocode_query) { "&key=&sensor=false" }

  let(:company) { Entity.find_by(name: 'Example Slovak Company') }

  let(:person1) { Entity.find_by(name: 'Example Person 1') }
  let(:person2) { Entity.find_by(name: 'Example Person 2') }

  let(:person1_relationship) do
    Relationship.find_by(source: person1, target: company)
  end

  let(:person2_relationship) do
    Relationship.find_by(source: person2, target: company)
  end

  let(:company_number) { 1_234_567 }
  let(:company_address) { '1234/1 Example Street, Example Place, 12345' }

  let(:api_response) { file_fixture('sk_bo_data.json').read }

  let(:raw_data) do
    JSON.parse(api_response)['value'][0].to_json
  end

  let(:raw_data_record) do
    RawDataRecord.find_by(etag: RawDataRecord.etag(raw_data))
  end

  before do
    Entity.__elasticsearch__.create_index! force: true

    # Mock the SK api, first page and a second (end) page
    stub_request(:get, sk_api_url).with(query: sk_query)
      .to_return(body: api_response)
    stub_request(:get, sk_api_url).with(query: "#{sk_query}&$skip=20")
      .to_return(body: file_fixture('sk_bo_data_end.json').read)

    # Mock the OpenCorporates api
    stub_oc_company_api_with_fixture('sk', company_number)

    # Mock the Google Geocode API
    query_address = CGI.escape(company_address)
    stub_request(:get, "#{google_geocode_api_url}#{query_address}#{google_geocode_query}")
      .to_return(body: file_fixture('google_geocode_api_response_sk.json').read)

    SkImportTrigger.new.call(data_source, 1)
    Sidekiq::Worker.drain_all

    # Force ES to index the documents right now (normally it waits 1 second)
    Entity.__elasticsearch__.refresh_index!
  end

  it 'imports the data and links it up correctly' do
    expect(company).not_to be_nil
    expect(person1).not_to be_nil
    expect(person2).not_to be_nil
    expect(person1_relationship).not_to be_nil
    expect(person2_relationship).not_to be_nil
    expect(raw_data_record).not_to be_nil

    search_for 'Example Slovak Company'
    click_link 'Example Slovak Company'
    expect(page).to have_text(company_address)
    expect(page).to have_link(person1.name)
    expect(page).to have_link(person2.name)
    click_link "", href: relationship_href(person1_relationship)
    expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
    expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"

    visit raw_entity_path(company)
    expect(page).to have_text(JSON.pretty_generate(JSON.parse(raw_data)).gsub(/\s+/, ' '), normalize_ws: true)

    search_for person1.name
    expect(page).to have_link person1.name

    visit raw_entity_path(person1)
    expect(page).to have_text(JSON.pretty_generate(JSON.parse(raw_data)).gsub(/\s+/, ' '), normalize_ws: true)

    search_for person2.name
    expect(page).to have_link person2.name

    visit raw_entity_path(person2)
    expect(page).to have_text(JSON.pretty_generate(JSON.parse(raw_data)).gsub(/\s+/, ' '), normalize_ws: true)
  end
end
