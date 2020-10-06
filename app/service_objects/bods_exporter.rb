class BodsExporter
  attr_accessor :chunk_size, :export

  def initialize(existing_ids: nil, chunk_size: 100, incremental: false)
    @existing_ids = existing_ids
    @export = BodsExport.create!
    @chunk_size = chunk_size
    @incremental = incremental
  end

  def call
    redis = Redis.new
    @export.create_output_folders
    load_existing_ids_into_redis(redis)
    entity_ids_to_export.each_slice(@chunk_size) do |chunk|
      BodsExportWorker.perform_async(chunk, @export.id.to_s)
    end
  ensure
    redis&.close
  end

  def entity_ids_to_export
    entities = Entity.legal_entities.no_timeout
    if @incremental
      last_export = BodsExport.most_recent
      unless last_export.nil?
        entities = entities.where(:updated_at.gt => last_export.created_at)
      end
    end
    entities.pluck(:id).map(&:to_s)
  end

  def load_existing_ids_into_redis(redis)
    return if @existing_ids.nil?

    redis.sadd(BodsExport::REDIS_ALL_STATEMENTS_SET, @existing_ids)
  end
end
