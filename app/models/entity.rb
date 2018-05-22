class Entity
  include ActsAsEntity
  include Elasticsearch::Model

  UNKNOWN_ID_MODIFIER = "-unknown".freeze

  field :identifiers, type: Array, default: []

  has_many :relationships_as_source, class_name: "Relationship", inverse_of: :source
  has_many :_relationships_as_target, class_name: "Relationship", inverse_of: :target
  has_many :statements

  index({ identifiers: 1 }, unique: true, sparse: true)
  index(type: 1)

  index_name "#{Rails.application.class.parent_name.underscore}_#{Rails.env}"

  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0,
  }

  mapping do
    indexes :name
    indexes :name_transliterated
    indexes :type, index: :not_analyzed
    indexes :country_code, index: :not_analyzed
    indexes :lang_code, index: :not_analyzed
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
    self.identifiers = document.fetch('identifiers')
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
    as_json(only: [:name, :type, :lang_code], methods: [:name_transliterated, :country_code])
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

  OC_IDENTIFIER_KEYS = %w(jurisdiction_code company_number).sort.freeze

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

  def oc_identifier
    identifiers.find { |i| i.keys.map(&:to_s).sort == OC_IDENTIFIER_KEYS }
  end
end

class DuplicateEntitiesDetected < StandardError
  attr_reader :criteria

  def initialize(msg, criteria)
    super(msg)
    @criteria = criteria
  end
end
