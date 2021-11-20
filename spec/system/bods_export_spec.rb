require 'rails_helper'

RSpec.describe 'BODS Export' do
  include BodsExportHelpers

  let(:exporter) { BodsExporter.new(incremental: true) }
  let(:export) { exporter.export }
  let(:uploader) { BodsExportUploader.new(export.id, incremental: true) }
  let(:bucket) { ENV['BODS_EXPORT_S3_BUCKET_NAME'] }
  let(:latest_statements_url) { "https://#{ENV['BODS_EXPORT_S3_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statements.latest.jsonl.gz" }
  let(:latest_ids_url) { "https://#{ENV['BODS_EXPORT_S3_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statement-ids.latest.txt.gz" }
  let(:redis) { Redis.new }

  let(:s3_adapter) { Rails.application.config.s3_adapter.new }

  before do
    expect(Rails.application.config.s3_adapter).to(
      receive(:new)
        .with(hash_including(:access_key_id, :secret_access_key))
        .and_return(s3_adapter),
    )
  end

  def export_statements_url(export)
    "https://#{ENV['BODS_EXPORT_S3_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statements.#{export.created_at.iso8601}.jsonl.gz"
  end

  def export_ids_url(export)
    "https://#{ENV['BODS_EXPORT_S3_BUCKET_NAME']}.s3.eu-west-1.amazonaws.com/public/exports/statement-ids.#{export.created_at.iso8601}.txt.gz"
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

    subject { run_export(export) }

    it_behaves_like 'a well-behaved BODS output'
  end

  context 'exporting changed data' do
    include_context 'BODS: company that is part of a chain of relationships'

    let!(:existing_statements) do
      [
        {
          'statementID' => legal_entity2_id,
          'statementType' => 'entityStatement',
          'entityType' => 'registeredEntity',
          'name' => legal_entity2.name,
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
          'statementID' => legal_entity2_natural_person_relationship_id,
          'statementType' => 'ownershipOrControlStatement',
          'statementDate' => '2017-01-23',
          'subject' => {
            'describedByEntityStatement' => legal_entity2_id,
          },
          'interestedParty' => {
            'describedByPersonStatement' => natural_person_id,
          },
          'interests' => [
            {
              'type' => 'shareholding',
              'share' => {
                'exact' => 100,
                'minimum' => 100,
                'maximum' => 100,
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
          'statementID' => legal_entity1_id,
          'statementType' => 'entityStatement',
          'entityType' => 'registeredEntity',
          'name' => legal_entity1.name,
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
          'statementID' => legal_entity1_legal_entity2_relationship_id,
          'statementType' => 'ownershipOrControlStatement',
          'statementDate' => '2017-01-23',
          'subject' => {
            'describedByEntityStatement' => legal_entity1_id,
          },
          'interestedParty' => {
            'describedByEntityStatement' => legal_entity2_id,
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
            'description' => 'GB Persons Of Significant Control Register',
            'url' => 'http://www.example.com',
            'retrievedAt' => retrieved_at.iso8601,
          },
        },
      ]
    end

    let!(:existing_statement_ids) { existing_statements.map { |s| s["statementID"] } }

    let(:exporter) { BodsExporter.new(existing_ids: existing_statement_ids, incremental: true) }

    before do
      # Update an entity in the middle of the chain
      legal_entity2.name = "Company B Updated"
      legal_entity2.save!
      # Without this, embedded document fields don't get stringified and the
      # bods mapping fails
      legal_entity2.reload

      # Create the new statement for it
      mapper = BodsMapper.new
      new_legal_entity2_statement = mapper.entity_statement(legal_entity2).as_json
      # Create new statements for the entity's relationships
      new_legal_entity1_legal_entity2_statement = mapper.ownership_or_control_statement(relationships.first.reload).as_json
      new_legal_entity2_natural_person_statement = mapper.ownership_or_control_statement(relationships.second.reload).as_json

      # We expect the update to change both the entity statement and therefore
      # the relationships which point to it, but not the other entities
      @new_expected_statements = existing_statements + [
        new_legal_entity2_statement,
        new_legal_entity1_legal_entity2_statement,
        new_legal_entity2_natural_person_statement,
      ]

      # rubocop:disable Style/StringConcatenation
      s3_adapter.upload_to_s3_without_file(
        s3_bucket: bucket,
        s3_path: 'public/exports/statements.latest.jsonl.gz',
        content: existing_statements.map { |s| Oj.dump(s, mode: :rails) }.join("\n") + "\n",
      )
      s3_adapter.upload_to_s3_without_file(
        s3_bucket: bucket,
        s3_path: 'public/exports/statement-ids.latest.txt.gz',
        content: existing_statement_ids.join("\n") + "\n",
      )
      # rubocop:enable Style/StringConcatenation
    end

    subject do
      run_export(export)
    end

    it_behaves_like 'a well-behaved BODS output' do
      let(:expected_statements) { @new_expected_statements }
    end
  end
end
