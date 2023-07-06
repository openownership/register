class InferredRelationship2
    def initialize(source:, target:, sourced_relationships:)
        @source = source
        @target = target
        @sourced_relationships = sourced_relationships
        @tmp = {}
    end

    attr_reader :source, :target, :sourced_relationships

    attr_accessor :interests

    def [](k)
        @tmp[k]
    end

    def []=(k, v)
        @tmp[k] = v
    end

    def intermediate_entities
        return [] unless sourced_relationships.any?

        sourced_relationships[1..].map(&:source)
    end

    def started_date
        return nil if sourced_relationships.length != 1

        sourced_relationships.first.started_date
    end

    def ended_date
        return nil unless sourced_relationships.any?

        relationship = sourced_relationships.detect { |r| r.ended_date.present? } # rubocop:disable Style/CollectionMethods
        relationship.try(:ended_date)
    end

    def is_indirect # rubocop:disable Naming/PredicateName
        return nil unless sourced_relationships.any?

        sourced_relationships.any?(&:is_indirect)
    end
end
