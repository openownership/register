require 'ostruct'
require 'register_sources_psc/repositories/company_record_repository'

class RawDataRecordRepository
  def initialize
    @repository = RegisterSourcesPsc::Repositories::CompanyRecordRepository.new
  end

  def all_for_entity(entity)
    bods_identifiers = entity.identifiers # identifier_converter.convert_v1_to_v2 entity.identifiers

    return [] if bods_identifiers.empty?

    get_by_bods_identifiers(bods_identifiers) # .order_by(updated_at: :desc, created_at: :desc)
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
