# frozen_string_literal: true

require 'ostruct'
require 'register_common/utils/paginated_array'
require 'register_sources_bods/structs/identifier'
require 'register_sources_dk/repository'
require 'register_sources_psc/repository'
require 'register_sources_sk/repository'

class RawDataRecordRepository
  DEFAULT_PER_PAGE = 20

  SearchResult = Struct.new(:record, :score)

  class SearchResults < Array
    def initialize(arr, total_count: nil, aggs: nil)
      @total_count = total_count || arr.to_a.count
      @aggs = aggs

      super(arr)
    end

    attr_reader :total_count, :aggs
  end

  def initialize
    @psc_repository = RegisterSourcesPsc::Repository.new(index: RegisterSourcesPsc::Config::ELASTICSEARCH_INDEX_COMPANY)
    @sk_repository = RegisterSourcesSk::Repository.new(index: RegisterSourcesSk::Config::ELASTICSEARCH_INDEX)
    @dk_repository = RegisterSourcesDk::Repository.new(index: RegisterSourcesDk::Config::ELASTICSEARCH_INDEX)

    @repositories = [
      @psc_repository,
      @sk_repository,
      @dk_repository
    ]
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def all_for_entity(main_entity, per_page: 10, page: 1)
    return all_for_entity(main_entity.master_entity, per_page:, page:) if main_entity.master_entity

    bods_identifiers = []

    [
      main_entity,
      main_entity.relationships_as_source,
      main_entity.relationships_as_target
    ].flatten.map(&:bods_statement).each do |bods_statement|
      bods_identifiers += bods_statement.identifiers if bods_statement.respond_to?(:identifiers)

      next unless bods_statement.respond_to?(:source)

      source = bods_statement.source
      next unless source

      s = source.url.to_s.split('https://api.company-information.service.gov.uk')
      next unless s.length > 1

      bods_identifiers += [RegisterSourcesBods::Identifier.new(
        schemeName: 'GB Persons Of Significant Control Register',
        id: s[1]
      )]
    end

    return [] if bods_identifiers.empty?

    get_by_bods_identifiers(bods_identifiers.uniq, per_page:, page:)
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def newest_for_entity_date(entity)
    raw_record = all_for_entity(entity).first
    raw_record_date(entity, raw_record)
  end

  def oldest_for_entity_date(entity)
    raw_record = all_for_entity(entity).last
    raw_record_date(entity, raw_record)
  end

  def newest_for_entity(entity)
    all_for_entity(entity).first
  end

  def oldest_for_entity(entity)
    all_for_entity(entity).last
  end

  private

  attr_reader :psc_repository, :dk_repository, :sk_repository, :repositories

  def client
    repositories.map(&:client).first
  end

  # rubocop:disable Metrics/PerceivedComplexity
  def get_by_bods_identifiers(identifiers, per_page:, page:)
    queries = repositories.map do |repository|
      repository.build_get_by_bods_identifiers(identifiers)
    end.flatten.compact

    if (page.to_i >= 1) && (per_page.to_i >= 1)
      page = page.to_i
      per_page = per_page.to_i
      from = (page - 1) * per_page
    else
      page = 1
      per_page = 10
      from = nil
    end

    results =
      if !client || queries.empty?
        {}
      else
        client.search(
          index: '*',
          body: {
            query: {
              bool: {
                should: queries
              }
            },
            from:,
            size: per_page
          }.compact
        )
      end

    res = process_results(results)

    RegisterCommon::Utils::PaginatedArray.new(
      res.map(&:record),
      current_page: page,
      records_per_page: per_page,
      total_count: res.total_count
    )
  end
  # rubocop:enable Metrics/PerceivedComplexity

  # rubocop:disable Metrics/CyclomaticComplexity
  def process_results(results)
    hits = results.dig('hits', 'hits') || []
    hits = hits.sort_by { |hit| hit['_score'] }.reverse
    total_count = results.dig('hits', 'total', 'value') || 0

    mapped = hits.map do |hit|
      case hit['_index']
      when psc_repository.send(:index)
        SearchResult.new(map_psc_es_record(hit['_source']), hit['_score'])
      when dk_repository.send(:index)
        SearchResult.new(map_dk_es_record(hit['_source']), hit['_score'])
      when sk_repository.send(:index)
        SearchResult.new(map_sk_es_record(hit['_source']), hit['_score'])
      end
    end.compact

    SearchResults.new(
      mapped.sort_by(&:score).reverse,
      total_count:,
      aggs: results['aggregations']
    )
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def raw_record_date(entity, raw_record)
    entity_date = (entity.bods_statement.source&.retrievedAt ||
                   entity.bods_statement.publicationDetails.publicationDate)&.to_date

    case raw_record
    when RegisterSourcesDk::Deltagerperson, RegisterSourcesSk::Record
      entity_date
    when RegisterSourcesPsc::CompanyRecord
      raw_record.data.notified_on.to_date
    end
  end

  def map_psc_es_record(record)
    RegisterSourcesPsc::CompanyRecord.new(record)
  end

  def map_sk_es_record(record)
    RegisterSourcesSk::Record[record['data']]
  end

  def map_dk_es_record(record)
    RegisterSourcesDk::Deltagerperson[record['Vrdeltagerperson']]
  end
end
