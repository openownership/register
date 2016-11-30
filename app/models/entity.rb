class Entity
  include Mongoid::Document

  field :name, type: String
  field :company_number, type: String
end
