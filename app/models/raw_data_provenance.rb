class RawDataProvenance
  include Mongoid::Document
  include Mongoid::Timestamps

  # Note we don't index this separately because of the compound index below
  # which mongodb can use instead.
  belongs_to :entity_or_relationship, polymorphic: true
  belongs_to :import, index: true
  has_and_belongs_to_many :raw_data_records, index: true, inverse_of: nil # rubocop:disable Rails/HasAndBelongsToMany

  index(
    entity_or_relationship_id: 1,
    entity_or_relationship_type: 1,
    import_id: 1,
  )

  def self.bulk_upsert_for_import(import, provenances)
    bulk_operations = provenances.map do |raw_record_id, entities_and_relationships|
      next unless entities_and_relationships.is_a? Array
      now = Time.zone.now
      entities_and_relationships.map do |entity_or_relationship|
        {
          update_one: {
            upsert: true,
            filter: {
              entity_or_relationship_id: entity_or_relationship.id,
              entity_or_relationship_type: entity_or_relationship.class.name,
              import_id: import.id,
            },
            update: {
              '$setOnInsert' => {
                entity_or_relationship_id: entity_or_relationship.id,
                entity_or_relationship_type: entity_or_relationship.class.name,
                import_id: import.id,
                created_at: now,
              },
              '$set' => { updated_at: now },
              '$addToSet' => { raw_data_record_ids: raw_record_id },
            },
          },
        }
      end
    end.flatten.compact

    collection.bulk_write(bulk_operations, ordered: false)
  end
end
