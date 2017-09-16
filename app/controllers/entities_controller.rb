class EntitiesController < ApplicationController
  def show
    @entity = Entity.find(params[:id])

    @source_relationships = @entity.relationships_as_source

    @ultimate_source_relationship_groupings = RelationshipGraph.new(@entity).ultimate_source_relationships.group_by { |r| r.source.name }.sort

    @opencorporates_company_hash = get_opencorporates_company_hash(@entity)

    @similar_people = @entity.natural_person? && Entity.search(
      query: Search.query(search_params),
      aggs: Search.aggregations,
    ).limit(11)
  end

  def tree
    @entity = Entity.find(params[:id])
    @node = TreeNode.new(@entity)
  end

  private

  def search_params
    { q: @entity.name, type: 'natural-person' }
  end

  def get_opencorporates_company_hash(entity)
    return unless entity.jurisdiction_code? && entity.company_number?

    client = OpencorporatesClient.new
    client.http.read_timeout = 1.0
    client.get_company(entity.jurisdiction_code, entity.company_number, sparse: false)
  end
end
