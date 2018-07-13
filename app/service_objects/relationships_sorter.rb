class RelationshipsSorter
  def initialize(relationships)
    @relationships = relationships
  end

  def call
    return @relationships if @relationships.blank?

    # We need to handle all forms of relationships here

    first_obj = @relationships.first
    case first_obj
    when Relationship, InferredRelationship
      @relationships.sort do |a, b|
        comparison_function(
          a.ended_date.try(:to_date),
          b.ended_date.try(:to_date),
        )
      end
    when Submissions::Relationship
      @relationships
    else
      raise ArgumentError, "Unexpected object detected - class: #{first_obj.class.name}"
    end
  end

  private

  def comparison_function(a, b)
    if a && b
      # Reverse ordering if both have values
      b <=> a
    else
      # At least one of them is nil so place this higher in ordering
      a ? 1 : -1
    end
  end
end
