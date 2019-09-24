class Import
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :data_source, index: true
  # Explicitly not adding the reverse habtm for raw_data_records here because
  # it will be huge and it's a performance hog during imports to add records to
  # it.

  validates :data_source, presence: true

  def self.all_for_entity(entity)
    where(
      'id' => {
        '$in' => RawDataProvenance.all_for_entity(entity).distinct(:import_id),
      },
    )
  end
end
