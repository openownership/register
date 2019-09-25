require 'rails_helper'

RSpec.describe 'BODS Export' do
  include BodsExportHelpers

  let(:exporter) { BodsExporter.new }
  let(:export) { exporter.export }
  let(:uploader) { BodsExportUploader.new(export.id) }
  let(:latest_statements_url) { "https://#{ENV['BUCKETEER_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statements.latest.jsonl.gz" }
  let(:latest_ids_url) { "https://#{ENV['BUCKETEER_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statement-ids.latest.txt.gz" }
  let(:redis) { Redis.new }

  def export_statements_url(export)
    "https://#{ENV['BUCKETEER_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statements.#{export.created_at.iso8601}.jsonl.gz"
  end

  def export_ids_url(export)
    "https://#{ENV['BUCKETEER_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz"
  end

  def stub_upload_of_latest_files
    stub_request(:put, latest_statements_url).to_return(status: 200, body: "")
    stub_request(:put, latest_ids_url).to_return(status: 200, body: "")
  end

  def stub_copy_to_export_files(export)
    stub_request(:head, latest_statements_url).to_return(status: 200, body: "")
    stub_request(:head, latest_ids_url).to_return(status: 200, body: "")

    stub_request(:post, export_statements_url(export)).with(query: "uploads")
      .to_return(status: 200, body: "")
    stub_request(:post, export_ids_url(export)).with(query: "uploads")
      .to_return(status: 200, body: "")

    stub_request(:put, export_statements_url(export))
      .to_return(status: 200, body: "")
    stub_request(:put, export_ids_url(export))
      .to_return(status: 200, body: "")
  end

  def run_export(export)
    with_temp_output_dir(export) do |dir|
      exporter.call
      Sidekiq::Worker.drain_all
      uploader.call
      file = File.join(dir, 'statements.latest.jsonl.gz')
      Zlib::GzipReader.open(file, &:readlines).map { |l| Oj.load(l.chomp, mode: :rails) }
    end
  end

  # RSpec's defaults aren't very helpful for seeing diffs in big json files
  original_max_length = nil

  before do
    original_max_length = RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length
    RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 100_000
  end

  after(:each) do
    redis.flushdb
    redis.close
  end

  after do
    RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = original_max_length
  end

  context "exporting initial data" do
    include_context 'BODS: company that is part of a chain of relationships'

    before do
      stub_request(:head, latest_statements_url).with(query: "partNumber=1").to_return(status: 404, body: "")
      stub_request(:head, latest_ids_url).with(query: "partNumber=1").to_return(status: 404, body: "")
      stub_upload_of_latest_files
      stub_copy_to_export_files(export)
    end

    subject { run_export(export) }

    it_behaves_like 'a well-behaved BODS output'
  end

  context 'exporting changed data' do
    include_context 'BODS: company that is part of a chain of relationships'

    let!(:existing_statements) do
      [
        {
          'statementID' => legal_entity_2_id,
          'statementType' => 'entityStatement',
          'entityType' => 'registeredEntity',
          'name' => legal_entity_2.name,
          'identifiers' => [
            {
              'scheme' => 'DK-CVR',
              'id' => '67890',
            },
          ],
          'foundingDate' => 2.months.ago.to_date.iso8601,
          'dissolutionDate' => 1.month.ago.to_date.iso8601,
          'addresses' => [
            {
              'type' => 'registered',
              'address' => '1234 hidden street',
              'country' => 'DK',
            },
          ],
        },
        {
          'statementID' => natural_person_id,
          'statementType' => 'personStatement',
          'personType' => 'knownPerson',
          'names' => [
            'type' => 'individual',
            'fullName' => natural_person.name,
          ],
          'identifiers' => [
            {
              'scheme' => 'MISC-Denmark CVR',
              'id' => 'P123456',
            },
          ],
          'nationalities' => [
            {
              'name' => 'United Kingdom of Great Britain and Northern Ireland',
              'code' => 'GB',
            },
          ],
          'birthDate' => 50.years.ago.to_date.iso8601,
          'addresses' => [
            {
              'address' => '25 road street',
              'country' => 'GB',
            },
          ],
        },
        {
          'statementID' => legal_entity_2_natural_person_relationship_id,
          'statementType' => 'ownershipOrControlStatement',
          'statementDate' => '2017-01-23',
          'subject' => {
            'describedByEntityStatement' => legal_entity_2_id,
          },
          'interestedParty' => {
            'describedByPersonStatement' => natural_person_id,
          },
          'interests' => [
            {
              'type' => 'shareholding',
              'share' => {
                'exact' => 100,
              },
            },
            {
              'type' => 'voting-rights',
              'share' => {
                'minimum' => 25,
                'maximum' => 49.99,
                'exclusiveMinimum' => false,
                'exclusiveMaximum' => false,
              },
            },
            {
              'type' => 'influence-or-control',
              'details' => 'significant-influence-or-control',
            },
          ],
          'source' => {
            'type' => ['officialRegister'],
            'description' => 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])',
            'url' => 'http://www.example.com',
            'retrievedAt' => retrieved_at.iso8601,
          },
        },
        {
          'statementID' => legal_entity_1_id,
          'statementType' => 'entityStatement',
          'entityType' => 'registeredEntity',
          'name' => legal_entity_1.name,
          'identifiers' => [
            {
              'scheme' => 'GB-COH',
              'id' => '12345',
            },
          ],
          'foundingDate' => 2.months.ago.to_date.iso8601,
          'dissolutionDate' => 1.month.ago.to_date.iso8601,
          'addresses' => [
            {
              'type' => 'registered',
              'address' => '123 not hidden street',
              'country' => 'GB',
            },
          ],
        },
        {
          'statementID' => legal_entity_1_legal_entity_2_relationship_id,
          'statementType' => 'ownershipOrControlStatement',
          'statementDate' => '2017-01-23',
          'subject' => {
            'describedByEntityStatement' => legal_entity_1_id,
          },
          'interestedParty' => {
            'describedByEntityStatement' => legal_entity_2_id,
          },
          'interests' => [
            {
              'type' => 'shareholding',
              'details' => 'ownership-of-shares-25-to-50-percent',
              'share' => {
                'minimum' => 25,
                'maximum' => 50,
                'exclusiveMinimum' => true,
                'exclusiveMaximum' => false,
              },
            },
            {
              'type' => 'voting-rights',
              'details' => 'voting-rights-50-to-75-percent',
              'share' => {
                'minimum' => 50,
                'maximum' => 75,
                'exclusiveMinimum' => true,
                'exclusiveMaximum' => true,
              },
            },
            {
              'type' => 'influence-or-control',
              'details' => 'significant-influence-or-control',
            },
            {
              'type' => 'influence-or-control',
              'details' => 'blah nlah nlah',
            },
          ],
          'source' => {
            'type' => ['officialRegister'],
            'description' => 'UK PSC Register',
            'url' => 'http://www.example.com',
            'retrievedAt' => retrieved_at.iso8601,
          },
        },
      ]
    end

    let!(:existing_statement_ids) { existing_statements.map { |s| s["statementID"] } }

    let(:exporter) { BodsExporter.new(existing_ids: existing_statement_ids) }

    before do
      sio = StringIO.new
      sio.binmode
      gz = Zlib::GzipWriter.new(sio)
      gz.write existing_statements.map { |s| Oj.dump(s, mode: :rails) }.join("\n") + "\n"
      gz.close
      existing_statements_file = sio.string

      sio = StringIO.new
      sio.binmode
      gz = Zlib::GzipWriter.new(sio)
      gz.write existing_statement_ids.join("\n") + "\n"
      gz.close
      existing_ids_file = sio.string

      # Update an entity in the middle of the chain
      legal_entity_2.name = "Company B Updated"
      legal_entity_2.save!
      # Without this, embedded document fields don't get stringified and the
      # bods mapping fails
      legal_entity_2.reload

      # Create the new statement for it
      mapper = BodsMapper.new
      new_legal_entity_2_statement = mapper.entity_statement(legal_entity_2).as_json
      # Create new statements for the entity's relationships
      new_legal_entity_1_legal_entity_2_statement = mapper.ownership_or_control_statement(relationships.first.reload).as_json
      new_legal_entity_2_natural_person_statement = mapper.ownership_or_control_statement(relationships.second.reload).as_json

      # We expect the update to change both the entity statement and therefore
      # the relationships which point to it, but not the other entities
      @new_expected_statements = existing_statements + [
        new_legal_entity_2_statement,
        new_legal_entity_1_legal_entity_2_statement,
        new_legal_entity_2_natural_person_statement,
      ]

      stub_request(:head, latest_statements_url).with(query: "partNumber=1")
        .to_return(status: 200, headers: { 'content-length' => existing_statements_file.bytesize })
      stub_request(:head, latest_ids_url).with(query: "partNumber=1")
        .to_return(status: 200, headers: { 'content-length' => existing_statements_file.bytesize })
      stub_request(:get, latest_statements_url).to_return(status: 200, body: existing_statements_file)
      stub_request(:get, latest_ids_url).to_return(status: 200, body: existing_ids_file)
      stub_upload_of_latest_files
      stub_copy_to_export_files(export)
    end

    subject do
      run_export(export)
    end

    it_behaves_like 'a well-behaved BODS output' do
      let(:expected_statements) { @new_expected_statements }
    end
  end
end
