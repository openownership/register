class Entity
  include Mongoid::Document
  include Elasticsearch::Model

  field :name, type: String

  embeds_many :identifiers

  index_name "#{Rails.application.class.parent_name.underscore}_#{Rails.env}"

  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }

  def as_indexed_json(_options = {})
    as_json(only: [:name])
  end
end
