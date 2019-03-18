class EntitiesController < ApplicationController
  def show
    entity = Entity.includes(:master_entity, :merged_entities).find(params[:id])
    redirect_to_master_entity(:show, entity)

    # It's annoying that we're going to paginate this straight after and so
    # throw away a lot of the relationships we find, but it's the only way to
    # sort them by target name and date, because MongoDB can't do that directly.
    source_relationships = decorate(
      RelationshipsSorter.new(entity.relationships_as_source).call,
    )
    @source_relationships = Kaminari
      .paginate_array(source_relationships)
      .page(params[:page]).per(10)

    @ultimate_source_relationship_groups = decorate_with(
      ultimate_source_relationship_groups(entity),
      UltimateSourceRelationshipGroupDecorator,
    )

    unless request.format.json?
      @similar_people = entity.natural_person? ? decorate(similar_people(entity)) : nil
    end

    @entity = decorate(entity)

    respond_to do |format|
      format.html
      format.json do
        relationships = (
          @source_relationships +
          @ultimate_source_relationship_groups.map do |g|
            g[:relationships].map(&:sourced_relationships)
          end.flatten.compact
        )

        serializer = BodsSerializer.new(
          relationships,
          BodsMapper.instance,
        )

        render json: serializer.statements
      end
    end
  end

  def tree
    entity = Entity.find(params[:id])
    redirect_to_master_entity(:show, entity)
    @node = decorate_with(TreeNode.new(entity), TreeNodeDecorator)
    @entity = decorate(entity)
  end

  def opencorporates_additional_info
    entity = Entity.find(params[:id])
    begin
      @opencorporates_company_hash = get_opencorporates_company_hash(entity)
    rescue OpencorporatesClient::TimeoutError
      @oc_api_timed_out = true
    end
    render partial: 'opencorporates_additional_info'
  end

  private

  def redirect_to_master_entity(action, entity)
    redirect_to(action: action, id: entity.master_entity.id.to_s) if entity.master_entity.present?
  end

  def ultimate_source_relationship_groups(entity)
    label_for = ->(r) { r.source.id.to_s.include?('statement') ? rand : r.source.name }

    relationships = RelationshipGraph.new(entity).ultimate_source_relationships

    RelationshipsSorter.new(relationships).call
      .uniq { |r| r.sourced_relationships.first.keys_for_uniq_grouping }
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

    client = OpencorporatesClient.new_for_app timeout: 2.0
    client.get_company(entity.jurisdiction_code, entity.company_number, sparse: false)
  end
end
