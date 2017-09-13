class SubmissionImporter
  def initialize(submission, entity_resolver: EntityResolver.new)
    @submission = submission
    @entity_resolver = entity_resolver
  end

  def import
    @submission.relationships.each(&method(:relationship!))
  end

  private

  def entity!(submission_entity)
    entity = Entity.new(submission_entity.attributes_for_submission)

    @entity_resolver.resolve!(entity) if submission_entity.legal_entity?

    unless entity.identifiers.any?
      entity.assign_attributes(
        identifiers: [{
          'submission_id' => @submission.id,
          'entity_id' => submission_entity.id,
        }],
      )
    end

    entity.upsert
    entity.tap(&method(:index_entity))
  end

  def index_entity(entity)
    IndexEntityService.new(entity).call
  end

  def relationship!(submission_relationship)
    Relationship.new(
      _id: {
        'submission_id' => @submission.id,
        'relationship_id' => submission_relationship.id,
      },
      source: entity!(submission_relationship.source),
      target: entity!(submission_relationship.target),
      interests: submission_relationship.interests,
      sample_date: sample_date,
      provenance: provenance,
    ).tap(&:upsert)
  end

  def sample_date
    @submission.submitted_at.to_date.to_s
  end

  def provenance
    Provenance.new(
      source_url: "https://register.openownership.org",
      source_name: "OpenOwnership Register",
      retrieved_at: @submission.submitted_at,
      imported_at: Time.now.utc,
    )
  end
end
