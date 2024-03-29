# frozen_string_literal: true

require 'register_common/utils/paginated_array'

class EntitiesController < ApplicationController
  RAW_DATA_RECORD_REPOSITORY = Rails.application.config.raw_data_record_repository
  ENTITY_SERVICE = Rails.application.config.entity_service

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def show
    entity_id = params[:id]

    @sentity = ENTITY_SERVICE.find_by_entity_id(entity_id) # rubocop:disable Rails/DynamicFindBy
    entity = @sentity

    raise ActionController::RoutingError, 'Not Found' unless entity

    redirect_to_master_entity?(:show, entity) && return

    @merged_entities = entity.merged_entities # .page(params[:merged_page]).per(10)

    @source_relationships = RegisterCommon::Utils::PaginatedArray.new(entity.relationships_as_source)
    # .order_by(started_date: :desc)
    # .page(params[:source_page]).per(10)

    @ultimate_source_relationship_groups = # decorate_with(
      ultimate_source_relationship_groups2(entity) # ,
    # UltimateSourceRelationshipGroupDecorator,
    # )

    @ultimate_source_relationship_groups.map! { |group| OpenStruct.new(group) } # rubocop:disable Style/OpenStructUse

    unless request.format.json?
      @similar_people = entity.natural_person? ? similar_people(entity) : nil
    end

    @data_source_names = [
      entity.relationships_as_source,
      entity.relationships_as_target
    ].flatten.compact.map(&:provenance).map(&:source_name).uniq.sort

    # Conversion
    @oc_data = get_opencorporates_company_hash(entity, sparse: true) || {}

    respond_to do |format|
      format.html
      format.json do
        relationships = (
          # Not just the paginated ones we show in HTML, all of them
          @sentity.relationships_as_source +
          @ultimate_source_relationship_groups.map do |g|
            g[:relationships].map(&:sourced_relationships)
          end.flatten.compact
        )

        statements = [
          BodsSerializer.new(relationships).statements,
          entity.bods_statement,
          entity.master_entity&.bods_statement,
          entity.merged_entities.map(&:bods_statement)
        ].compact.flatten.uniq(&:statementID)

        statements = BodsStatementSorter.new.sort_statements(statements)

        render json: JSON.pretty_generate(statements.as_json)
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def graph
    entity = ENTITY_SERVICE.find_by_entity_id(params[:id]) # rubocop:disable Rails/DynamicFindBy
    raise ActionController::RoutingError, 'Not Found' unless entity

    redirect_to_master_entity?(:graph, entity) && return
    @graph = decorate(EntityGraph.new(entity))
    @sentity = entity
  end

  def raw
    entity = ENTITY_SERVICE.find_by_entity_id(params[:id]) # rubocop:disable Rails/DynamicFindBy
    raise ActionController::RoutingError, 'Not Found' unless entity

    redirect_to_master_entity?(:raw, entity) && return
    @sentity = entity
    @raw_data_records = RAW_DATA_RECORD_REPOSITORY.all_for_entity(entity, per_page: 10,
                                                                          page: [params[:page].to_i, 1].max)
    @oc_data = get_opencorporates_company_hash(entity, sparse: true) || {}
    return if @raw_data_records.empty?

    @newest = RAW_DATA_RECORD_REPOSITORY.newest_for_entity_date(entity)
    @oldest = RAW_DATA_RECORD_REPOSITORY.oldest_for_entity_date(entity)

    data_source_klasses = @raw_data_records.map do |raw_record|
      raw_record.class.to_s
    end.compact.uniq.sort
    @data_sources = Rails.configuration.x.data_sources.filter do |_, data_source|
      data_source_klasses.include?(data_source[:class])
    end
  end

  def opencorporates_additional_info
    entity = ENTITY_SERVICE.find_by_entity_id(params[:id]) # rubocop:disable Rails/DynamicFindBy
    raise ActionController::RoutingError, 'Not Found' unless entity

    @sentity = entity
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
      action:,
      id: entity.master_entity.id.to_s,
      format: params[:format]
    )
    true
  end

  def ultimate_source_relationship_groups2(entity)
    # label_for = ->(r) { r.source.is_a?(UnknownPersonsEntity) || r.source.name.blank? ? rand : r.source.name }
    label_for = ->(r) { r.source.name.presence || rand }

    relationships = InferredRelationshipGraph2.new(entity).ultimate_source_relationships

    RelationshipsSorter.new(relationships).call
                       .uniq { |r| r.sourced_relationships.first.keys_for_uniq_grouping }
                       .group_by(&label_for)
                       .map do |label, rels|
      {
        label:,
        label_lang_code: rels.first.source.lang_code,
        relationships: rels
      }
    end
  end

  def similar_people(entity)
    ENTITY_SERVICE.search({ q: entity.name, type: 'personStatement' }, exclude_identifiers: entity.identifiers)
  end

  def get_opencorporates_company_hash(entity, sparse: false)
    return unless entity.jurisdiction_code? && entity.company_number?

    client = OpencorporatesClient.new_for_app timeout: 5.0
    client.get_company(entity.jurisdiction_code, entity.company_number, sparse:)
  end
end
