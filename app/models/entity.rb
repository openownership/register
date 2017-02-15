class Entity
  include Mongoid::Document
  include Elasticsearch::Model

  field :name, type: String

  embeds_many :identifiers
  index({ identifiers: 1 }, unique: true, sparse: true)

  index_name "#{Rails.application.class.parent_name.underscore}_#{Rails.env}"

  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }

  def jurisdiction_code
    identifiers.map { |identifier| identifier._id['jurisdiction_code'] }.compact.first
  end

  # Similar to Mongoid::Persistable::Upsertable#upsert except that entities
  # are found using their embeddeded identifiers instead of the _id field.
  def upsert
    selector = {
      identifiers: identifiers.first.as_document
    }

    attributes = as_document.except('_id')

    document = collection.find_one_and_update(selector, attributes, upsert: true, return_document: :after)

    self.id = document.fetch('_id')
  rescue Mongo::Error::OperationFailure => exception
    raise unless exception.message.start_with?('E11000')

    retry
  end

  def as_indexed_json(_options = {})
    as_json(only: [:name])
  end
end
