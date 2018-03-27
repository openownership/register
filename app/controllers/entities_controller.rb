class EntitiesController < ApplicationController
  def show
    entity = Entity.find(params[:id])

    @opencorporates_company_hash = get_opencorporates_company_hash(entity)

    @source_relationships = decorate(
      RelationshipsSorter.new(entity.relationships_as_source).call,
    )

    @ultimate_source_relationship_groups = decorate_with(
      ultimate_source_relationship_groups(entity),
      UltimateSourceRelationshipGroupDecorator,
    )

    @similar_people = entity.natural_person? ? decorate(similar_people(entity)) : nil

    @entity = decorate(entity)
  end

  def tree
    entity = Entity.find(params[:id])
    @node = decorate_with(TreeNode.new(entity), TreeNodeDecorator)
    @entity = decorate(entity)
  end

  private

  def ultimate_source_relationship_groups(entity)
    label_for = ->(r) { r.source.id.to_s.include?('statement') ? rand : r.source.name }

    relationships = RelationshipGraph.new(entity).ultimate_source_relationships

    RelationshipsSorter.new(relationships).call
      .group_by(&label_for)
      .map do |label, rels|
        {
          label: label,
          label_lang_code: rels.first.source.lang_code,
          relationships: rels,
        }
      end
  end

  def similar_people(entity)
    Entity.search(
      query: Search.query(q: entity.name, type: 'natural-person'),
      aggs: Search.aggregations,
    ).limit(11).records.to_a
  end

  def get_opencorporates_company_hash(entity)
    return unless entity.jurisdiction_code? && entity.company_number?

    client = OpencorporatesClient.new
    client.http.open_timeout = 1.0
    client.http.read_timeout = 1.0
    client.get_company(entity.jurisdiction_code, entity.company_number, sparse: false)
  end
end
