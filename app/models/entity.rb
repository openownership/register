class Entity
  include Mongoid::Document
  include Elasticsearch::Model

  field :name, type: String
  field :company_number, type: String

  index_name "#{Rails.application.class.parent_name.underscore}_#{Rails.env}"

  def as_indexed_json(_options = {})
    as_json(only: [:name])
  end
end
