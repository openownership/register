class EntityGraph
  include Draper::Decoratable

  MAX_LEVELS = 7
  MAX_RELATIONSHIPS = 25
  attr_accessor :entity, :nodes, :edges

  def initialize(entity)
    @entity = entity
    @nodes = Set[]
    @edges = Set[]
    visit(entity, :relationships_as_target, :source)
    visit(entity, :relationships_as_source, :target)
  end

  # Perform a depth-first search through the given entities relationships, in the
  # direction specified by the frontier and end_node accessors.
  # Will stop at MAX_LEVELS nodes from the start node and will bail out on
  # any node which has more than MAX_RELATIONSHIPS.
  # Populates @nodes and @edges with Node and Edge instances for everything it
  # visits, or LabelNode and LabelEdge instances where it bails out.
  def visit(entity, frontier, end_node, seen = Set[], level = 1)
    return if seen.include?(entity.id.to_s)
    seen.add entity.id.to_s
    @nodes.add Node.new(entity)
    relationships = entity.send(frontier)
    relationships_size = relationships.size
    if level > MAX_LEVELS && relationships_size.positive?
      label_node(entity, "max_levels", frontier, count: relationships_size)
      return
    elsif relationships_size > MAX_RELATIONSHIPS
      label_node(entity, "max_relationships", frontier, count: relationships_size)
      return
    end
    level += 1
    relationships.each do |relationship|
      @edges.add Edge.new(relationship)
      visit(relationship.send(end_node), frontier, end_node, seen, level)
    end
  end

  class Node
    attr_accessor :entity

    def initialize(entity)
      @entity = entity
    end

    def id
      entity.id.to_s
    end

    def eql?(other)
      id == other.id
    end

    delegate :hash, to: :id
  end

  class LabelNode < Node
    attr_accessor :label_key, :label_data

    def initialize(entity, label_key, label_data)
      @label_key = label_key
      @label_data = label_data
      super(entity)
    end

    def id
      "#{super}_#{label_key}"
    end

    delegate :hash, to: :id
  end

  class Edge
    attr_accessor :relationship, :source_id, :target_id, :id

    def initialize(relationship)
      @relationship = relationship
      @source_id = relationship.source.id.to_s
      @target_id = relationship.target.id.to_s
      @id = SecureRandom.uuid
    end

    def eql?(other)
      relationship == other.relationship
    end

    delegate :hash, to: :relationship
  end

  class LabelEdge < Edge
    attr_accessor :entity, :node

    def initialize(entity, node, direction)
      @entity = entity
      @node = node
      if direction == :from
        @target_id = node.id
        @source_id = entity.id.to_s
      else
        @source_id = node.id
        @target_id = entity.id.to_s
      end

      @id = "#{@source_id}_#{@target_id}"
    end

    def eql?(other)
      id == other.id
    end

    delegate :hash, to: :id
  end

  private

  def label_node(entity, key, frontier, data)
    direction = frontier == :relationships_as_source ? :from : :to
    label_key = "#{key}_#{frontier}"
    label_node = LabelNode.new(entity, label_key, data)
    @nodes.add label_node
    @edges.add LabelEdge.new(entity, label_node, direction)
  end
end
