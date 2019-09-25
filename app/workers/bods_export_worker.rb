class BodsExportWorker
  include Sidekiq::Worker

  REDIS_POOL = ConnectionPool.new(size: Sidekiq.options[:concurrency], timeout: 3) { Redis.new }

  def perform(entity_ids, export_id)
    @export = BodsExport.find(export_id)
    @mapper = BodsMapper.instance
    @job_statements_set = "#{BodsExport::REDIS_ALL_STATEMENTS_SET}:#{export_id}:#{jid}"

    entities = Entity
      .includes(
        :_relationships_as_target,
        :_relationships_as_source,
        :master_entity,
        :statements,
      )
      .find(entity_ids)

    relationships = entities.map do |entity|
      ultimate_source_relationships = InferredRelationshipGraph
        .new(entity)
        .ultimate_source_relationships.map(&:sourced_relationships).flatten
      entity.relationships_as_source + ultimate_source_relationships
    end.flatten.compact

    statements(relationships)
  ensure
    REDIS_POOL.with { |redis| redis.del @job_statements_set }
  end

  private

  def seen_statement_id?(statement_id)
    REDIS_POOL.with do |redis|
      redis.sismember(BodsExport::REDIS_ALL_STATEMENTS_SET, statement_id) \
        || redis.sismember(@job_statements_set, statement_id)
    end
  end

  def record_statements_in_job(statements)
    return if statements.empty?
    statement_ids = statements.map { |s| s[:statementID] }
    REDIS_POOL.with do |redis|
      redis.sadd(@job_statements_set, statement_ids)
    end
  end

  def record_created_statements(statements)
    return if statements.empty?
    statement_ids = statements.map { |s| s[:statementID] }
    REDIS_POOL.with do |redis|
      redis.multi do |multi|
        # Record it in the global set of seen statements
        multi.sadd(BodsExport::REDIS_ALL_STATEMENTS_SET, statement_ids)
        # Record it in the ordering for this export
        multi.rpush(@export.redis_statements_list, statement_ids)
      end
    end
  end

  def save_statements(statements)
    return if statements.empty?
    statements.each do |statement|
      filename = @export.statement_filename(statement[:statementID])
      File.open(filename, 'w') { |f| f.puts Oj.dump(statement, mode: :rails) }
    end
  end

  def statements(relationships)
    statements = []
    relationships.each do |relationship|
      relationship_statements = statements_for(relationship)
      statements.concat relationship_statements
      record_statements_in_job(relationship_statements)
    end

    save_statements(statements)
    record_created_statements(statements)
  end

  def statements_for(relationship)
    [
      statement_for_target(relationship.target),
      statement_for_source(relationship.source),
      statement_for_relationship(relationship),
    ].compact
  end

  def statement_for_target(entity)
    return nil if seen_statement_id? @mapper.statement_id(entity)

    @mapper.entity_statement(entity)
  end

  def statement_for_source(entity)
    return nil unless @mapper.generates_statement?(entity)
    return nil if seen_statement_id? @mapper.statement_id(entity)

    if entity.legal_entity?
      @mapper.entity_statement(entity)
    elsif entity.natural_person?
      @mapper.person_statement(entity)
    end
  end

  def statement_for_relationship(relationship)
    return if seen_statement_id? @mapper.statement_id(relationship)

    @mapper.ownership_or_control_statement(relationship)
  end
end
