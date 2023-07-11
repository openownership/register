require 'ostruct'
require 'register_sources_psc/repositories/company_record_repository'
require 'register_sources_bods/structs/identifier'

class RawDataRecordRepository
  def initialize
    @repository = RegisterSourcesPsc::Repositories::CompanyRecordRepository.new
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

  attr_reader :repository

  def get_by_bods_identifiers(identifiers)
    repository.get_by_bods_identifiers(identifiers)
  end
end
