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

  def self.all_for_entity(entity)
    where(
      'entity_or_relationship_id' => { '$in' => entity.all_ids },
      'entity_or_relationship_type' => 'Entity',
    )
  end
end
