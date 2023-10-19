# frozen_string_literal: true

class BodsSerializer
  def initialize(relationships)
    @relationships = relationships
  end

  def statements
    @relationships.reduce([]) do |acc, relationship|
      relationship.source
      relationship.target

      acc + [
        relationship,
        relationship.source,
        relationship.target,
        relationship.source&.relationships_as_source,
        relationship.source&.relationships_as_target,
        relationship.target&.relationships_as_source,
        relationship.target&.relationships_as_target
      ].flatten.compact.map(&:all_bods_statements).flatten
    end.uniq
  end
end
