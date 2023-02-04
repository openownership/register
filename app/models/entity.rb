module ElasticsearchImportingWithoutMergedPeople
  def import(options = {}, &block)
    unless options[:scope].present? || options[:query].present?
      options[:query] = -> { where(master_entity: nil) }
    end
    super(options, &block)
  end
end

class Entity
  include ActsAsEntity
  include Elasticsearch::Model
  singleton_class.prepend ElasticsearchImportingWithoutMergedPeople

  UNKNOWN_ID_MODIFIER = "-unknown".freeze

  field :identifiers, type: Array, default: []

  has_many :_relationships_as_source, class_name: "Relationship", inverse_of: :source
  has_many :_relationships_as_target, class_name: "Relationship", inverse_of: :target
  has_many :statements

  has_many :merged_entities, class_name: "Entity", inverse_of: :master_entity
  field :merged_entities_count, type: Integer
  belongs_to(
    :master_entity,
    class_name: "Entity",
    inverse_of: :merged_entities,
    optional: true,
    index: true,
    counter_cache: :merged_entities_count,
    touch: true,
  )
  has_many :raw_data_provenances, as: :entity_or_relationship

  field :oc_updated_at, type: Time
  field :last_resolved_at, type: Time
  # When this was last directly updated, different from updated_at which gets
  # bumped whenever a related relationship or merged entity is updated
  field :self_updated_at, type: Time

  index({ identifiers: 1 }, unique: true, sparse: true)
  index('identifiers.document_id' => 1)
  index(type: 1)
  index(jurisdiction_code: 1)
  index(dissolution_date: 1)
  index(last_resolved_at: 1)

  index_name "#{Rails.application.class.module_parent_name.underscore}_entities_#{Rails.env}"

  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0,
  }

  mapping do
    indexes :name
    indexes :name_transliterated
    indexes :type, type: :keyword
    indexes :country_code, type: :keyword
    indexes :lang_code, type: :keyword
    indexes :company_number, type: :keyword
  end

  def self.find_or_unknown(id)
    if id.to_s.include?('statement') || id.to_s.include?(UNKNOWN_ID_MODIFIER)
      UnknownPersonsEntity.new(id: id)
    else
      find(id)
    end
  end

  def relationships_as_target
    if type == Types::NATURAL_PERSON
      []
    else
      relationships = Relationship.includes(:target, :source).where(target_id: id)
      relationships.entries.presence || CreateRelationshipsForStatements.call(self)
    end
  end

  def relationships_as_source
    if merged_entities.empty?
      Relationship.includes(:target, :source, :raw_data_provenances).where(source_id: id)
    else
      self_and_merged_entity_ids = [id] + merged_entities.only(:_id)
      Relationship.includes(:target, :source, :raw_data_provenances).in(source_id: self_and_merged_entity_ids)
    end
  end

  def as_indexed_json(_options = {})
    as_json(only: %i[name type lang_code company_number], methods: %i[name_transliterated country_code])
  end

  scope :with_identifiers, ->(identifiers) {
    where(identifiers: { :$elemMatch => { :$in => identifiers } })
  }

  OC_IDENTIFIER_KEYS = %w[jurisdiction_code company_number].freeze
  OC_IDENTIFIER_KEYS_SET = OC_IDENTIFIER_KEYS.to_set.freeze

  def self.build_oc_identifier(data)
    OC_IDENTIFIER_KEYS.each_with_object({}) do |k, h|
      k_sym = k.to_sym
      raise "Cannot build OC identifier - data is missing required key '#{k}' - data = #{data.inspect}" unless data.key?(k_sym)

      h[k] = data[k_sym]
    end
  end

  def add_oc_identifier(data)
    identifiers << Entity.build_oc_identifier(data)
  end

  def oc_identifiers
    identifiers.select { |i| oc_identifier? i }
  end

  def oc_identifier
    identifiers.find { |i| oc_identifier? i }
  end

  def oc_identifier?(identifier)
    identifier.keys.map(&:to_s).to_set == OC_IDENTIFIER_KEYS_SET
  end

  def psc_self_link_identifier?(identifier)
    identifier['document_id'] == 'GB PSC Snapshot' && identifier.key?('link')
  end

  def psc_self_link_identifiers
    identifiers.select do |i|
      psc_self_link_identifier? i
    end
  end

  def set_self_updated_at
    self.self_updated_at = Time.zone.now
  end

  def all_ids
    [id] + merged_entity_ids
  end
end
