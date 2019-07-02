class RawDataProvenance
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :entity_or_relationship, polymorphic: true, index: true
  belongs_to :import, index: true
  has_and_belongs_to_many :raw_data_records, index: true, inverse_of: nil # rubocop:disable Rails/HasAndBelongsToMany
end
