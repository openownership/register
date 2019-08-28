require 'rails_helper'

RSpec.describe BodsExportWorker do
  include BodsExportHelpers

  def created_files(tmp_directory)
    old_wd = Dir.getwd
    Dir.chdir(tmp_directory)
    created = Dir.glob('**/*.json').map { |f| "#{tmp_directory}/#{f}" }
    Dir.chdir(old_wd)
    created
  end

  describe '#perform' do
    let(:relationship) { create(:relationship) }
    let(:legal_entity) { relationship.target }
    let(:export) { create(:bods_export) }
    let(:statements) do
      BodsSerializer.new([relationship], BodsMapper.instance).statements
    end
    let(:statement_ids) { statements.map { |s| s[:statementID] } }
    let(:redis) { Redis.new }

    after(:each) do
      redis.flushdb
    end

    subject do
      BodsExportWorker.new.perform([legal_entity.id.to_s], export.id.to_s)
    end

    it 'saves statements for the ownership chain of every entity' do
      with_temp_output_dir(export) do |dir|
        subject

        expected = statements.map { |s| export.statement_filename(s[:statementID]) }
        created = created_files(dir)
        expect(created).to match_array(expected)

        statements.each do |statement|
          json = File.read(export.statement_filename(statement[:statementID]))
          created_statement = Oj.load(json, mode: :rails, symbol_keys: true)
          expect(created_statement).to eq(statement)
        end
      end
    end

    it 'records the statement ids it created in Redis' do
      with_temp_output_dir(export) do
        subject

        seen = redis.smembers(BodsExport::REDIS_ALL_STATEMENTS_SET)
        expect(statement_ids).to match_array(seen)

        list = redis.lrange(export.redis_statements_list, 0, -1)
        # Note it should be in identical order, eq, not just identical elements
        expect(statement_ids).to eq(list)
      end
    end

    context "when a statement has already been seen in Redis" do
      let(:seen_id) { statement_ids.first }

      before do
        redis.sadd(BodsExport::REDIS_ALL_STATEMENTS_SET, seen_id)
      end

      it "doesn't recreate that statement" do
        with_temp_output_dir(export) do |dir|
          subject

          expected = statements.drop(1).map { |s| export.statement_filename(s[:statementID]) }
          created = created_files(dir)
          expect(created).to match_array(expected)
        end
      end

      it "doesn't add that statement id to the list for this export" do
        with_temp_output_dir(export) { subject }
        list = redis.lrange(export.redis_statements_list, 0, -1)
        # Note it should be in identical order, eq, not just identical elements
        expect(statement_ids.drop(1)).to eq(list)
      end
    end

    it "doesn't leave any other keys in Redis" do
      with_temp_output_dir(export) { subject }
      expected_keys = [
        BodsExport::REDIS_ALL_STATEMENTS_SET,
        export.redis_statements_list,
      ]
      expect(redis.keys('*')).to match_array(expected_keys)
    end

    context 'when entities share ownership chains' do
      let(:subsidiary_relationship) do
        create(:relationship, source: relationship.target)
      end
      let(:subsidiary) { subsidiary_relationship.target }

      let(:statements) do
        relationship_statements = BodsSerializer.new([relationship], BodsMapper.instance).statements
        subsidiary_statements = BodsSerializer.new([subsidiary_relationship], BodsMapper.instance).statements
        all_statements = relationship_statements + subsidiary_statements
        all_statements.uniq { |s| s[:statementID] }
      end

      subject do
        BodsExportWorker.new.perform([legal_entity.id.to_s], export.id.to_s)
        BodsExportWorker.new.perform([subsidiary.id.to_s], export.id.to_s)
      end

      it 'only creates statements once' do
        with_temp_output_dir(export) do
          statements.each do |statement|
            file = export.statement_filename(statement[:statementID])
            expect(File).to receive(:open).with(file, 'w').once
          end
          subject
        end
      end
    end
  end
end
