class Entity
  include ActsAsEntity
  include Elasticsearch::Model

  UNKNOWN_ID_MODIFIER = "-unknown".freeze

  scope :legal_entities, -> { where(type: Types::LEGAL_ENTITY) }

  field :identifiers, type: Array, default: []

  has_many :relationships_as_source, class_name: "Relationship", inverse_of: :source
  has_many :_relationships_as_target, class_name: "Relationship", inverse_of: :target

  index({ identifiers: 1 }, unique: true, sparse: true)
  index(type: 1)

  index_name "#{Rails.application.class.parent_name.underscore}_#{Rails.env}"

  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0,
  }

  mapping do
    indexes :name
    indexes :type, index: :not_analyzed
    indexes :country_code, index: :not_analyzed
  end

  def self.find_or_unknown(id)
    if id.include?(UNKNOWN_ID_MODIFIER)
      UnknownPersonsEntity.new(id: id)
    else
      find(id)
    end
  end

  def relationships_as_target
    if type == Types::NATURAL_PERSON
      []
    else
      _relationships_as_target.entries.presence || [Relationship.new(source: UnknownPersonsEntity.new(id: "#{id}-unknown"), target: self)]
    end
  end

  # Similar to Mongoid::Persistable::Upsertable#upsert except that entities
  # are found using their embeddeded identifiers instead of the _id field.
  def upsert
    selector = {
      identifiers: { :$in => identifiers },
    }

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

    retry
  end

  def as_indexed_json(_options = {})
    as_json(only: [:name, :type], methods: :country_code)
  end

  def relationships_as_target_excluding(ids)
    relationships_as_target.reject { |r| ids.include?(r.id) }
  end
end
