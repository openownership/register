class RawDataProvenance
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :entity_or_relationship, polymorphic: true
  belongs_to :import, index: true
  has_and_belongs_to_many :raw_data_records, index: true # rubocop:disable Rails/HasAndBelongsToMany
end
