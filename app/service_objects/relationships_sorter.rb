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
      @relationships.sort_by { |r| [ended_time(r), r.target.name.to_s] }
    else
      raise ArgumentError, "Unexpected object detected - class: #{first_obj.class.name}"
    end
  end

  private

  def ended_time(relationship)
    return 0 if relationship.ended_date.nil?

    relationship.ended_date.to_time.to_i
  end
end
