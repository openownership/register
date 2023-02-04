module SourceWithMasterEntity
  def source
    super.master_entity.presence || super
  end
end

class Relationship
  include Mongoid::Document
  include Mongoid::Timestamps::Updated
  prepend SourceWithMasterEntity

  field :_id, type: Hash

  field :interests, type: Array, default: []
  field :sample_date, type: ISO8601::Date
  field :started_date, type: ISO8601::Date
  field :ended_date, type: ISO8601::Date
  field :is_indirect, type: TrueClass

  belongs_to :source, class_name: 'Entity', inverse_of: :_relationships_as_source, touch: true
  belongs_to :target, class_name: 'Entity', inverse_of: :_relationships_as_target, touch: true

  embeds_one :provenance
  has_many :raw_data_provenances, as: :entity_or_relationship

  index source_id: 1
  index target_id: 1
  index type: 1
  index '_id.document_id' => 1
  index ended_date: 1

  def keys_for_uniq_grouping
    interest_types = interests.map do |i|
      case i
      when Hash
        i.fetch('type', '')
      when String
        i
      end
    end
    [source.id.to_s, target.id.to_s] + interest_types.sort
  end
end
