class EntitiesController < ApplicationController
  def show
    entity = Entity.includes(:master_entity).find(params[:id])
    redirect_to_master_entity(:show, entity)

    @merged_entities = entity.merged_entities.page(params[:merged_page]).per(10)

    @source_relationships = entity
      .relationships_as_source
      .order_by(started_date: :desc)
      .page(params[:source_page]).per(10)

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
          # Not just the paginated ones we show in HTML, all of them
          entity.relationships_as_source +
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
    redirect_to_master_entity(:tree, entity)
    @node = decorate_with(TreeNode.new(entity), TreeNodeDecorator)
    @entity = decorate(entity)
  end

  def graph
    entity = Entity.find(params[:id])
    redirect_to_master_entity(:graph, entity)
    @graph = decorate(EntityGraph.new(entity))
    @entity = decorate(entity)
  end

  def raw
    entity = Entity.find(params[:id])
    redirect_to_master_entity(:raw, entity)
    @entity = decorate(entity)
    @raw_data_records = RawDataRecord.all_for_entity(entity)
      .includes(:imports)
      .order_by(updated_at: :desc, created_at: :desc)
      .page(params[:page])
      .per(10)
    @newest = RawDataRecord.newest_for_entity(entity).updated_at
    @oldest = RawDataRecord.oldest_for_entity(entity).created_at
    @data_sources = DataSource.all_for_entity(entity)
    @latest_imports = latest_imports_by_data_source(@data_sources)
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
    label_for = ->(r) { r.source.is_a?(UnknownPersonsEntity) || r.source.name.blank? ? rand : r.source.name }

    relationships = InferredRelationshipGraph.new(entity).ultimate_source_relationships

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

  def latest_imports_by_data_source(data_sources)
    data_sources.map do |ds|
      [ds.id.to_s, ds.imports.desc(:created_at).pluck(:created_at).first]
    end.to_h
  end
end
