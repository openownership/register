class EntityMergeDecider
  def initialize(e1, e2)
    @e1 = e1
    @e2 = e2
  end

  # Returns: [ entity_to_remove, entity_to_keep ]
  def call
    if @e1.oc_identifier
      [@e2, @e1]
    elsif @e2.oc_identifier
      [@e1, @e2]

    # rubocop:disable Lint/DuplicateBranch
    else
      [@e2, @e1]
    end
    # rubocop:enable Lint/DuplicateBranch
  end
end
