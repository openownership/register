require 'xxhash'

class RawDataRecord
  include Mongoid::Document
  include Mongoid::Timestamps

  RAW_DATA_COMPRESSION_LIMIT = 1_000_000 # 1MB
  MONGODB_MAX_DOC_SIZE = 16_000_000 # 16MB (slightly lower than real life limit)

  field :etag, type: String
  field :raw_data, type: String
  field :compressed, type: Boolean
  has_and_belongs_to_many :imports, index: true, inverse_of: nil # rubocop:disable Rails/HasAndBelongsToMany

  validates :raw_data, presence: true
  validates :etag, presence: true

  attr_readonly :raw_data, :etag

  index({ etag: 1 }, unique: true)

  class << self
    extend Memoist

    def bulk_upsert_for_import(records, import)
      now = Time.zone.now
      bulk_operations = records.map do |record|
        raw_data, compressed = compress_if_needed record[:raw_data]
        etag = record[:etag].presence || etag(raw_data)
        if raw_data.bytesize > MONGODB_MAX_DOC_SIZE
          Rollbar.error "[#{self.class.name}] Raw data is too large for MongoDB even when compressed, skipping record with etag: #{etag}"
          next
        end
        {
          update_one: {
            upsert: true,
            filter: { etag: etag },
            update: {
              '$setOnInsert' => {
                etag: etag,
                raw_data: raw_data,
                compressed: compressed,
                created_at: now,
              },
              '$set' => { updated_at: now },
              '$addToSet' => { import_ids: import.id },
            },
          },
        }
      end.compact

      collection.bulk_write(bulk_operations, ordered: false)
    end

    def etag(data)
      XXhash.xxh64(data).to_s
    end

    def compress_if_needed(raw_data)
      compressed = false
      compressed_raw_data = raw_data
      if raw_data.bytesize > RAW_DATA_COMPRESSION_LIMIT
        compressed_raw_data = compress_raw_data(raw_data)
        compressed = true
      end
      [compressed_raw_data, compressed]
    end

    def compress_raw_data(raw_data)
      Base64.encode64 Zlib::Deflate.deflate(raw_data)
    end

    def decompress_raw_data(raw_data)
      Zlib::Inflate.inflate Base64.decode64(raw_data)
    end

    def all_ids_for_entity(entity)
      RawDataProvenance.all_for_entity(entity)
        .pluck(:raw_data_record_ids)
        .flatten
        .compact
    end
    memoize :all_ids_for_entity

    def all_for_entity(entity)
      where('id' => { '$in' => all_ids_for_entity(entity) })
    end

    def newest_for_entity(entity)
      # Records get updated when they're seen again, so the newest one is the one
      # that's been most recently updated, not created (although if it's brand
      # new)
      where('id' => { '$in' => all_ids_for_entity(entity) })
        .desc(:updated_at)
        .first
    end

    def oldest_for_entity(entity)
      where('id' => { '$in' => all_ids_for_entity(entity) })
        .asc(:created_at)
        .first
    end
  end

  def raw_data
    compressed ? self.class.decompress_raw_data(self[:raw_data]) : self[:raw_data]
  end

  def data_sources
    imports.map(&:data_source).uniq
  end

  def most_recent_import
    imports.desc(:created_at).first
  end

  def seen_in_most_recent_import?
    most_recent_import.data_source.most_recent_import.created_at <= updated_at
  end
end
