class EntitiesController < ApplicationController
  DATA_SOURCE_REPOSITORY = Rails.application.config.data_source_repository
  RAW_DATA_RECORD_REPOSITORY = Rails.application.config.raw_data_record_repository
  ENTITY_SERVICE = Rails.application.config.entity_service

  class PaginatedArray < Array
    def initialize(source_array, current_page: 0, records_per_page: 10, limit_value: nil, total_count: nil)
      @source_array = source_array

      @current_page = current_page
      @records_per_page = records_per_page
      @limit_value = limit_value
      @total_count = total_count || source_array.count

      super(source_array)
    end

    attr_reader :current_page, :limit_value, :total_count
  
    def limit(n)
      new_limit = [limit_value, n].compact.min
      PaginatedArray.new(source_array[0...new_limit], current_page: current_page, records_per_page: records_per_page, limit_value: new_limit, total_count: total_count)
    end
  
    def page(page_num)
      PaginatedArray.new(source_array[0...n], current_page: page_num, records_per_page: records_per_page, limit_value: limit_value, total_count: total_count)
    end

    def per(max_per_page)
      PaginatedArray.new(source_array[0...n], current_page: current_page, records_per_page: max_per_page, limit_value: limit_value, total_count: total_count)
    end

    def total_pages
      (total_count / records_per_page).ceil
    end

    def order_by(**args)
      self
    end

    def offset_value
      current_page * records_per_page
    end

    private

    attr_reader :records_per_page, :source_array
  end

  def show
    entity_id = params[:id]

    @sentity = ENTITY_SERVICE.find_by_entity_id(entity_id)
    entity = @sentity

    unless entity
      raise ActionController::RoutingError.new('Not Found')
    end
    
    redirect_to_master_entity?(:show, entity) && return

    @merged_entities = entity.merged_entities # .page(params[:merged_page]).per(10)

    @source_relationships = PaginatedArray.new(entity.relationships_as_source)
      # .order_by(started_date: :desc)
      # .page(params[:source_page]).per(10)

    @ultimate_source_relationship_groups = # decorate_with(
      ultimate_source_relationship_groups2(entity)#,
      # UltimateSourceRelationshipGroupDecorator,
    # )

    @ultimate_source_relationship_groups.map! { |group| OpenStruct.new(group) }

    unless request.format.json?
      @similar_people = entity.natural_person? ? similar_people(entity) : nil
    end

    raw_records = RAW_DATA_RECORD_REPOSITORY.all_for_entity(entity)
    @data_source_names = DATA_SOURCE_REPOSITORY.data_source_names_for_raw_records(raw_records)

    unless @data_source_names.empty?
      @newest_raw_record = RAW_DATA_RECORD_REPOSITORY.newest_for_entity_date(entity)
      @raw_record_count = raw_records.size
    end

    # Conversion
    @oc_data = get_opencorporates_company_hash(entity) || {}

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
        ].compact.flatten.uniq { |s| s.statementID }

        render json: JSON.pretty_generate(statements.as_json)
      end
    end
  end

  def graph
    entity = ENTITY_SERVICE.find_by_entity_id(params[:id])
    unless entity
      raise ActionController::RoutingError.new('Not Found')
    end
    redirect_to_master_entity?(:graph, entity) && return
    @graph = decorate(EntityGraph.new(entity))
    @sentity = entity
  end

  def raw
    entity = ENTITY_SERVICE.find_by_entity_id(params[:id])
    unless entity
      raise ActionController::RoutingError.new('Not Found')
    end
    redirect_to_master_entity?(:raw, entity) && return
    @sentity = entity
    @raw_data_records = RAW_DATA_RECORD_REPOSITORY.all_for_entity(entity)
    return if @raw_data_records.empty?

    @oc_data = get_opencorporates_company_hash(entity) || {}
    @newest = RAW_DATA_RECORD_REPOSITORY.newest_for_entity_date(entity)
    @oldest = RAW_DATA_RECORD_REPOSITORY.oldest_for_entity_date(entity)
    @data_sources = DATA_SOURCE_REPOSITORY.all_for_raw_records(@raw_data_records)
  end

  def opencorporates_additional_info
    entity = ENTITY_SERVICE.find_by_entity_id(params[:id])
    unless entity
      raise ActionController::RoutingError.new('Not Found')
    end
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
      action: action,
      id: entity.master_entity.id.to_s,
      format: params[:format],
    )
    true
  end

  def ultimate_source_relationship_groups2(entity)
    # label_for = ->(r) { r.source.is_a?(UnknownPersonsEntity) || r.source.name.blank? ? rand : r.source.name }
    label_for = ->(r) { r.source.name.blank? ? rand : r.source.name }

    relationships = InferredRelationshipGraph2.new(entity).ultimate_source_relationships

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
    ENTITY_SERVICE.search({ q: entity.name, type: 'personStatement' }, exclude_identifiers: entity.identifiers)
  end

  def get_opencorporates_company_hash(entity)
    return unless entity.jurisdiction_code? && entity.company_number?

    client = OpencorporatesClient.new_for_app timeout: 2.0
    client.get_company(entity.jurisdiction_code, entity.company_number, sparse: false)
  end
end
