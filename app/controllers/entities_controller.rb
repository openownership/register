class EntitiesController < ApplicationController
  ENTITY_REPOSITORY = Rails.application.config.entity_repository
  DATA_SOURCE_REPOSITORY = Rails.application.config.data_source_repository
  RAW_DATA_RECORD_REPOSITORY = Rails.application.config.raw_data_record_repository

  def show
    entity = ENTITY_REPOSITORY.find_with_master_entity(params[:id])
    redirect_to_master_entity?(:show, entity) && return

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

    @data_source_names = DATA_SOURCE_REPOSITORY.data_source_names_for_entity(entity)
    unless @data_source_names.empty?
      @newest_raw_record = RAW_DATA_RECORD_REPOSITORY.newest_for_entity(entity).updated_at
      @raw_record_count = RAW_DATA_RECORD_REPOSITORY.all_for_entity(entity).size
    end

    @entity = decorate(entity)

    respond_to do |format|
      format.html
      format.json do
        # We cache some large JSON output to reduce load, but we're selective
        # so we can't do the usual Rails.cache.fetch with a block
        cache_key = "#{entity.cache_key}/bods_statements"
        statements = Rails.cache.read(cache_key)
        if statements.blank?
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

          # It's only worth caching large entities which are expensive to
          # traverse all the relationships for
          if serializer.statements.size > 20
            Rails.cache.write(cache_key, serializer.statements.to_json)
          end

          statements = serializer.statements.to_json
        end

        render json: statements
      end
    end
  end

  def graph
    entity = ENTITY_REPOSITORY.find(params[:id])
    redirect_to_master_entity?(:graph, entity) && return
    @graph = decorate(EntityGraph.new(entity))
    @entity = decorate(entity)
  end

  def raw
    entity = ENTITY_REPOSITORY.find(params[:id])
    redirect_to_master_entity?(:raw, entity) && return
    @entity = decorate(entity)
    @raw_data_records = RAW_DATA_RECORD_REPOSITORY.all_for_entity_with_imports(entity).page(params[:page]).per(10)
    return if @raw_data_records.empty?

    @newest = RAW_DATA_RECORD_REPOSITORY.newest_for_entity(entity).updated_at
    @oldest = RAW_DATA_RECORD_REPOSITORY.oldest_for_entity(entity).created_at
    @data_sources = DATA_SOURCE_REPOSITORY.all_for_entity(entity)
  end

  def opencorporates_additional_info
    entity = ENTITY_REPOSITORY.find(params[:id])
    begin
      @opencorporates_company_hash = get_opencorporates_company_hash(entity)
    rescue OpencorporatesClient::TimeoutError
      @oc_api_timed_out = true
    end
    render partial: 'opencorporates_additional_info'
  end

  private

  def redirect_to_master_entity?(action, entity)
    return false if entity.master_entity.blank?

    redirect_to(
      action: action,
      id: entity.master_entity.id.to_s,
      format: params[:format],
    )
    true
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
    ENTITY_REPOSITORY.search(
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
