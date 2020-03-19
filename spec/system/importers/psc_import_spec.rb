require 'zip'
require 'rails_helper'

RSpec.describe 'PSC Import' do
  include EntityHelpers
  include SearchHelpers

  let(:data_source) { create(:psc_data_source) }
  let(:filename) { 'psc-snapshot-2019-06-13_2of14' }
  let(:download_page) { "<a href=\"#{filename}.zip\">#{filename}.zip</a>" }
  let(:data_url) do
    data_source_uri = URI.parse(data_source.url)
    base_url = "#{data_source_uri.scheme}://#{data_source_uri.host}"
    "#{base_url}/#{filename}.zip"
  end
  let(:record) { file_fixture('psc_individual.json').read }
  let(:zip_file) do
    stream = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry "#{filename}.json"
      zip.print record
    end
    stream.rewind
    stream.string
  end

  let(:person) do
    Entity.find_by('identifiers.link' => '/company/01234567/persons-with-significant-control/individual/abcdef123456789')
  end
  let(:company_number) { '01234567' }
  let(:company) { Entity.find_by('company_number' => company_number) }
  let(:relationship) do
    Relationship.find_by(source: person, target: company)
  end

  let(:raw_data_record) do
    RawDataRecord.find_by(etag: '17794693706902436288')
  end
  let(:person_provenance) do
    person.raw_data_provenances.where(raw_data_records: raw_data_record)
  end
  let(:company_provenance) do
    company.raw_data_provenances.where(raw_data_records: raw_data_record)
  end
  let(:relationship_provenance) do
    relationship.raw_data_provenances.where(raw_data_records: raw_data_record)
  end

  before do
    Entity.__elasticsearch__.create_index! force: true

    # Mock the main page download
    stub_request(:get, data_source.url).to_return(body: download_page)

    # Mock the individual zip download
    stub_request(:get, data_url).to_return(
      body: ->(_r) { zip_file },
      headers: { "Content-Encoding" => "zip" },
    )

    # Mock the call to the OpenCorporates API
    stub_oc_company_api_with_fixture('gb', company_number)

    PscImportTrigger.new.call(data_source, 1)
    Sidekiq::Worker.drain_all

    # Force ES to index the documents right now (normally it waits 1 second)
    Entity.__elasticsearch__.refresh_index!
  end

  it 'imports the data and links it up correctly' do
    expect(person).not_to be_nil
    expect(company).not_to be_nil
    expect(relationship).not_to be_nil
    expect(raw_data_record).not_to be_nil
    expect(person_provenance).not_to be_nil
    expect(company_provenance).not_to be_nil
    expect(relationship_provenance).not_to be_nil

    search_for 'Example'
    click_link 'EXAMPLE LTD'
    expect(page).to have_link(person.name)
    click_link "", href: relationship_href(relationship)
    expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
    expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"

    expected_json = JSON.pretty_generate JSON.parse(record)
    visit raw_entity_path(company)
    expect(page).to have_text expected_json

    visit raw_entity_path(person)
    expect(page).to have_text expected_json
  end
end
