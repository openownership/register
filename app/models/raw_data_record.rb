class RawDataRecord
  include Mongoid::Document
  include Mongoid::Timestamps

  field :data, type: Hash
  field :etag, type: String
  has_and_belongs_to_many :imports, index: true # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :raw_data_provenances, index: true # rubocop:disable Rails/HasAndBelongsToMany

  attr_readonly :data, :etag

  validates :data, presence: true
  validates :etag, presence: true

  index({ etag: 1 }, unique: true)
end
