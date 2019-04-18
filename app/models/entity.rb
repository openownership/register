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
  field :merged_entities_count, type: Integer, default: 0
  belongs_to(
    :master_entity,
    class_name: "Entity",
    inverse_of: :merged_entities,
    optional: true,
    index: true,
    counter_cache: :merged_entities_count,
  )

  index({ identifiers: 1 }, unique: true, sparse: true)
  index('identifiers.document_id' => 1)
  index(type: 1)
  index(jurisdiction_code: 1)
  index(dissolution_date: 1)

  index_name "#{Rails.application.class.parent_name.underscore}_entities_#{Rails.env}"

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
      UnknownPersonsEntity.new(id: id, name: id)
    else
      find(id)
    end
  end

  def relationships_as_target
    if type == Types::NATURAL_PERSON
      []
    else
      _relationships_as_target.entries.presence || CreateRelationshipsForStatements.call(self)
    end
  end

  def relationships_as_source
    if merged_entities.empty?
      Relationship.includes(:target, :source).where(source_id: id)
    else
      self_and_merged_entity_ids = [id] + merged_entities.only(:_id)
      Relationship.includes(:target, :source).in(source_id: self_and_merged_entity_ids)
    end
  end

  # Similar to Mongoid::Persistable::Upsertable#upsert except that entities
  # are found using their embeddeded identifiers instead of the _id field.
  def upsert
    selector = Entity.with_identifiers(identifiers).selector

    attributes = as_document.except('_id', 'identifiers')

    document = collection.find_one_and_update(
      selector,
      {
        :$addToSet => {
          identifiers: {
            :$each => identifiers,
          },
        },
        :$set => attributes,
      },
      upsert: true,
      return_document: :after,
    )

    self.id = document.fetch('_id')

    reload
  rescue Mongo::Error::OperationFailure => exception
    raise unless exception.message.start_with?('E11000')

    criteria = Entity.where(selector)
    if criteria.count > 1
      raise DuplicateEntitiesDetected.new(
        "Unable to upsert entity due to #{identifiers} matching multiple documents",
        criteria,
      )
    end

    retry
  end

  def as_indexed_json(_options = {})
    as_json(only: %i[name type lang_code company_number], methods: %i[name_transliterated country_code])
  end

  def to_builder
    Jbuilder.new do |json|
      json.id id.to_s
      json.type type
      json.name name
      json.address address

      case type
      when Types::NATURAL_PERSON
        json.nationality nationality
        json.country_of_residence country_of_residence
        json.dob dob&.atoms
      when Types::LEGAL_ENTITY
        json.jurisdiction_code jurisdiction_code
        json.company_number company_number
        json.incorporation_date incorporation_date
        json.dissolution_date dissolution_date
        json.company_type company_type
      end
    end
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
    identifiers.select { |i| i.keys.map(&:to_s).to_set == OC_IDENTIFIER_KEYS_SET }
  end

  def oc_identifier
    identifiers.find { |i| i.keys.map(&:to_s).to_set == OC_IDENTIFIER_KEYS_SET }
  end

  def psc_self_link_identifier?(identifier)
    identifier['document_id'] == 'GB PSC Snapshot' && identifier.key?('link')
  end

  def psc_self_link_identifiers
    identifiers.select do |i|
      psc_self_link_identifier? i
    end
  end
end

class DuplicateEntitiesDetected < StandardError
  attr_reader :criteria

  def initialize(msg, criteria)
    super(msg)
    @criteria = criteria
  end
end
