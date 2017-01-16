class Relationship
  include Mongoid::Document

  field :interests, type: Array

  belongs_to :source, class_name: 'Entity'
  belongs_to :target, class_name: 'Entity'
end
