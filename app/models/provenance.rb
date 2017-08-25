class Provenance
  include Mongoid::Document

  field :source_url, type: String
  field :source_name, type: String
  field :retrieved_at, type: Time
  field :imported_at, type: Time

  def to_builder
    Jbuilder.new do |json|
      json.source_url source_url
      json.source_name source_name
      json.retrieved_at retrieved_at
      json.imported_at imported_at
    end
  end
end
