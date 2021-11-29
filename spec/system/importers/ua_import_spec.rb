require 'rails_helper'

def extractor_missing?
  stdout, _stderr, _status = Open3.capture3('which ua-edr-extractor')
  stdout.blank? ? 'No ua-edr-extractor found, have you installed it or do you need to activate a venv?' : false
end

RSpec.describe 'UA Import' do
  include EntityHelpers
  include SearchHelpers

  let(:ckan_url) do
    'https://data.gov.ua/api/3/action/package_show?id=1c7f3815-3259-45e0-bdf1-64dca07ddc10'
  end
  let(:data_url) { 'http://example.com/ua-data.zip' }
  let(:ckan_data) do
    {
      'result' => {
        'resources' => [
          {
            url: data_url,
          },
        ],
      },
    }.to_json
  end
  let(:company_number) { '12345678' }
  let(:oc_api_url) do
    "https://api.opencorporates.com/v0.4.6/companies/ua/#{company_number}"
  end
  let(:oc_query) { 'api_token=&sparse=true' }
  let(:data_fixture) { Rails.root.join('spec/fixtures/files/ua_data.zip') }
  let(:company) { Entity.find_by(company_number: company_number) }
  # Vasya Pupkyn is a Russian 'John Smith', i.e. a generic name.
  # We need a real-looking name (not Example Person X) because we have to pass
  # the data through our named entity extraction process, which is trained on
  # what real names look like.
  # https://ru.wikipedia.org/wiki/%D0%92%D0%B0%D1%81%D1%8F_%D0%9F%D1%83%D0%BF%D0%BA%D0%B8%D0%BD
  let(:person) { Entity.find_by(name: 'вася пупкин') }
  let(:relationship) { Relationship.find_by(source: person, target: company) }

  before do
    Entity.__elasticsearch__.create_index! force: true

    stub_request(:get, ckan_url).to_return(body: ckan_data)
    stub_request(:get, data_url).to_return(body: File.binread(data_fixture))

    stub_oc_company_api_with_fixture('ua', company_number)

    Dir.mktmpdir { |dir| UaImportTrigger.new(dir).call }

    # Force ES to index the documents right now (normally it waits 1 second)
    Entity.__elasticsearch__.refresh_index!
  end

  it 'imports the data and links it up correctly', skip: extractor_missing? do
    expect(company).not_to be_nil
    expect(person).not_to be_nil
    expect(relationship).not_to be_nil

    search_for person.name
    click_link person.name

    expect(page).to have_link(company.name)

    click_link "", href: relationship_href(relationship)

    expect(page).to have_text "#{I18n.t('relationships.provenance.retrieved_at')} #{Time.zone.today}"
    expect(page).to have_text "#{I18n.t('relationships.provenance.imported_at')} #{Time.zone.today}"
  end
end
