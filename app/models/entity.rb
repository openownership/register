class Entity
  include Mongoid::Document
  include Elasticsearch::Model

  field :name, type: String
  field :company_number, type: String

  def as_indexed_json(_options = {})
    as_json(only: [:name])
  end
end
