class Import
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :data_source, index: true
  has_and_belongs_to_many :raw_data_records, index: true # rubocop:disable Rails/HasAndBelongsToMany

  validates :data_source, presence: true
end
