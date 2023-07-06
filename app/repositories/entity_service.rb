require 'register_sources_bods/repositories/bods_statement_repository'
require 'register_sources_bods/register/entity_service'

class EntityService < RegisterSourcesBods::Register::EntityService
  def initialize
    repository = RegisterSourcesBods::Repositories::BodsStatementRepository.new
    super(statement_repository: repository)
  end
end
