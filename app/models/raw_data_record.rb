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

  index({ etag: 1 }, unique: true)

  def self.bulk_upsert_for_import(records, import)
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

  def self.etag(data)
    XXhash.xxh64(data).to_s
  end

  def self.compress_if_needed(raw_data)
    compressed = false
    compressed_raw_data = raw_data
    if raw_data.bytesize > RAW_DATA_COMPRESSION_LIMIT
      compressed_raw_data = compress_raw_data(raw_data)
      compressed = true
    end
    [compressed_raw_data, compressed]
  end

  def self.compress_raw_data(raw_data)
    Base64.encode64 Zlib::Deflate.deflate(raw_data)
  end

  def self.decompress_raw_data(raw_data)
    Zlib::Inflate.inflate Base64.decode64(raw_data)
  end

  def raw_data
    compressed ? self.class.decompress_raw_data(self[:raw_data]) : self[:raw_data]
  end
end
