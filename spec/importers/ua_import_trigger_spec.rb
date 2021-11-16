require 'rails_helper'

RSpec.describe 'UaImportTrigger' do
  let(:extractor) { instance_double "UaExtractor" }
  let(:importer) { instance_double "UaImporter" }
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
  let(:ner_models_fixture) do
    Rails.root.join('spec', 'fixtures', 'files', 'ua_ner_models.tar.gz')
  end
  let(:data_fixture) do
    Rails.root.join('spec', 'fixtures', 'files', 'ua_data.zip')
  end
  let(:extracted_data_fixture) do
    Rails.root.join('spec', 'fixtures', 'files', 'ua_extracted_bo_data.json')
  end

  before do
    allow(importer).to receive(:parse).and_return(nil)

    allow(UaExtractor).to receive(:new).and_return(extractor)
    allow(UaImporter).to receive(:new).and_return(importer)

    stub_request(:get, ckan_url).to_return(body: ckan_data)
    stub_request(:get, data_url).to_return(body: File.binread(data_fixture))

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('UA_NER_MODELS').and_return(ner_models_fixture.to_s)
  end

  def stub_extraction(working_dir)
    allow(extractor).to receive(:call) do
      IO.copy_stream(
        File.open(extracted_data_fixture),
        File.join(working_dir, 'output.jsonl'),
      )
    end
  end

  it 'downloads the models specified in UA_NER_MODELS' do
    Dir.mktmpdir do |dir|
      stub_extraction(dir)
      UaImportTrigger.new(dir).call
      expected_models = [
        File.join(dir, 'models', 'model1.txt'),
        File.join(dir, 'models', 'model2.txt'),
      ]
      downloaded_models = Dir.glob("#{dir}/models/*")
      expect(downloaded_models).to match_array(expected_models)
    end
  end

  it 'downloads the latest data from NAIS' do
    Dir.mktmpdir do |dir|
      stub_extraction(dir)
      UaImportTrigger.new(dir).call
      expect(a_request(:get, ckan_url)).to have_been_made
      expect(a_request(:get, data_url)).to have_been_made
    end
  end

  it 'extracts the data using a UaExtractor instance' do
    Dir.mktmpdir do |dir|
      expected_input = File.join(dir, '15-UFOP_01.05.2019', '15.1-EX_XML_EDR_UO_14.05.2019.xml')
      expected_output = File.join(dir, 'output.jsonl')
      expect(UaExtractor).to receive(:new).with(expected_input, expected_output, dir).and_return(extractor)
      expect(extractor).to receive(:call) do
        IO.copy_stream(
          File.open(extracted_data_fixture),
          File.join(dir, 'output.jsonl'),
        )
      end
      UaImportTrigger.new(dir).call
    end
  end

  it 'calls a UaImporter with the extracted data file and necessary metadata' do
    Dir.mktmpdir do |dir|
      expect(UaImporter)
        .to(
          receive(:new)
          .with(
            hash_including(
              source_url: 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10',
              source_name: 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])',
              document_id: 'Ukraine EDR',
            ),
          ),
        )
        .and_return(importer)
      stub_extraction(dir)
      UaImportTrigger.new(dir).call
    end
  end
end
