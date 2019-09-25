class Provenance
  include Mongoid::Document

  field :source_url, type: String
  field :source_name, type: String
  field :retrieved_at, type: Time
  field :imported_at, type: Time

  embedded_in :relationship
end
