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

    get_by_bods_identifiers(bods_identifiers.uniq) # .order_by(updated_at: :desc, created_at: :desc)
  end

  def newest_for_entity(entity)
    all_for_entity(entity).last
  end

  def oldest_for_entity(entity)
    all_for_entity(entity).first
  end

  private

  attr_reader :psc_repository, :dk_repository, :sk_repository, :repositories

  def get_by_bods_identifiers(identifiers)
    repositories.map do |repository|
      repository.get_by_bods_identifiers(identifiers)
    end.flatten.compact
  end
end
