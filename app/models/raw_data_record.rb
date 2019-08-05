require 'xxhash'

class RawDataRecord
  include Mongoid::Document
  include Mongoid::Timestamps

  field :data, type: Hash
  field :etag, type: String
  field :raw_data, type: String
  has_and_belongs_to_many :imports, index: true, inverse_of: nil # rubocop:disable Rails/HasAndBelongsToMany

  validates :raw_data, presence: true
  validates :etag, presence: true

  index({ etag: 1 }, unique: true)

  def self.bulk_save_for_import(records, import)
    now = Time.zone.now
    bulk_operations = records.map do |record|
      raw_data = record[:raw_data]
      etag = record[:etag].presence || etag(raw_data)
      {
        update_one: {
          upsert: true,
          filter: { etag: etag },
          update: {
            '$setOnInsert' => { etag: etag, raw_data: raw_data, created_at: now },
            '$set' => { updated_at: now },
            '$addToSet' => { import_ids: import.id },
          },
        },
      }
    end

    collection.bulk_write(bulk_operations, ordered: false).upserted_ids
  end

  def self.etag(data)
    XXhash.xxh64(data).to_s
  end
end
