class Entity
  include Mongoid::Document
  include Elasticsearch::Model

  module Types
    NATURAL_PERSON = "natural-person".freeze
    LEGAL_ENTITY = "legal-entity".freeze
  end

  field :type, type: String

  field :name, type: String
  field :address, type: String

  field :nationality, type: String
  field :country_of_residence, type: String
  field :dob_year, type: Integer
  field :dob_month, type: Integer
  field :dob_day, type: Integer

  field :jurisdiction_code, type: String
  field :company_number, type: String
  field :incorporation_date, type: Date
  field :dissolution_date, type: Date
  field :company_type, type: String

  embeds_many :identifiers
  index({ identifiers: 1 }, unique: true, sparse: true)

  index_name "#{Rails.application.class.parent_name.underscore}_#{Rails.env}"

  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }

  def natural_person?
    type == Types::NATURAL_PERSON
  end

  def country
    if natural_person?
      return unless nationality
      ISO3166::Country[nationality]
    else
      return unless jurisdiction_code
      code, = jurisdiction_code.split('_')
      ISO3166::Country[code]
    end
  end

  def country_subdivision
    return if natural_person?
    return unless country
    _, code = jurisdiction_code.split('_')
    return unless code
    country.subdivisions[code.upcase]
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
