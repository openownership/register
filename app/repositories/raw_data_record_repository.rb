require 'ostruct'
require 'register_sources_psc/repositories/company_record_repository'
require 'register_sources_sk/repositories/record_repository'
require 'register_sources_dk/repositories/deltagerperson_repository'
require 'register_sources_bods/structs/identifier'

class RawDataRecordRepository
  def initialize
    @psc_repository = RegisterSourcesPsc::Repositories::CompanyRecordRepository.new
    @sk_repository = RegisterSourcesSk::Repositories::RecordRepository.new
    @dk_repository = RegisterSourcesDk::Repositories::DeltagerpersonRepository.new

    @repositories = [
      @psc_repository,
      @sk_repository,
      @dk_repository
    ]
  end

  def all_for_entity(main_entity)
    return all_for_entity(main_entity.master_entity) if main_entity.master_entity

    bods_identifiers = []

    [
      main_entity,
      main_entity.relationships_as_source,
      main_entity.relationships_as_target
    ].flatten.map(&:bods_statement).each do |bods_statement|
      if bods_statement.respond_to?(:identifiers)
        bods_identifiers += bods_statement.identifiers
      end

      if bods_statement.respond_to?(:source)
        source = bods_statement.source
        if source
          s = source.url.to_s.split("https://api.company-information.service.gov.uk")
          if s.length > 1
            bods_identifiers += [RegisterSourcesBods::Identifier.new(
              schemeName: 'GB Persons Of Significant Control Register',
              id: s[1]
            )]
          end
        end
      end
    end

    return [] if bods_identifiers.empty?

    get_by_bods_identifiers(bods_identifiers.uniq).sort_by { |raw_record| raw_record_date(main_entity, raw_record) }.reverse
  end

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

  def get_by_bods_identifiers(identifiers)
    repositories.map do |repository|
      repository.get_by_bods_identifiers(identifiers)
    end.flatten.compact
  end

  def raw_record_date(entity, raw_record)
    entity_date = (entity.bods_statement.source&.retrievedAt || entity.bods_statement.publicationDetails.publicationDate)&.to_date

    case raw_record
    when RegisterSourcesDk::Deltagerperson
      entity_date
    when RegisterSourcesPsc::CompanyRecord
      raw_record.data.notified_on.to_date
    when RegisterSourcesSk::Record
      entity_date
    end
  end
end
