class Relationship
  include Mongoid::Document

  belongs_to :source, class_name: 'Entity'
  belongs_to :target, class_name: 'Entity'
end
