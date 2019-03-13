class NaturalPersonsDuplicatesMerger
  FIELDS_TO_MATCH = %i[
    name
    address
    dob
  ].freeze

  def run
    stats = {}

    processed, candidates = build_candidates

    stats[:processed] = processed

    stats[:candidates] = candidates.size

    Rails.logger.info "[#{self.class.name}] #{candidates.size} separate groups of candidates found for merging - now merging…"

    merges = merge_candidates candidates

    stats[:merges] = merges

    Rails.logger.info "[#{self.class.name}] Run finished with stats: #{stats.to_json}"

    stats
  end

  private

  def build_candidates
    total = query.count
    processed = 0

    groups = Hash.new { |h, k| h[k] = [] }

    query.each do |entity|
      processed += 1

      Rails.logger.info "[#{self.class.name}] #{processed} out of #{total} natural_person entities processed" if (processed % 100_000).zero?

      key = build_key entity

      next if key.nil?

      groups[key] << entity._id.to_s
    end

    candidates = groups.select { |_, v| v.size > 1 }

    [
      processed,
      candidates,
    ]
  end

  def merge_candidates(candidates)
    candidates.reduce(0) do |count, (key, entity_ids)|
      entities = Entity.find entity_ids
      entity = merge_entities(entities)

      Rails.logger.info "[#{self.class.name}] For key '#{key}': merged #{entities.size} entities into one entity (ID: #{entity._id})"

      count + (entities.size - 1)
    end
  end

  def query
    @query ||= Entity.natural_persons
  end

  def build_key(entity)
    # If any of the fields are null/empty then no valid key can be generated

    data = FIELDS_TO_MATCH.each_with_object({}) do |field, acc|
      acc[field] = entity.send(field).to_s.presence
    end.freeze

    contains_empty_values = data.values.any?(&:nil?)

    contains_empty_values ? nil : data.values.join(' | ')
  end

  def merge_entities(entities)
    to_keep = entities.first
    entities.drop(1).each do |to_merge|
      NonDestructivePeopleMerger.new(to_merge, to_keep).call
    end
    to_keep
  end
end
