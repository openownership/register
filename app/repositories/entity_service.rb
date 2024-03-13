# frozen_string_literal: true

require 'register_sources_bods/register/entity_service'
require 'register_sources_bods/repository'

class EntityService < RegisterSourcesBods::Register::EntityService
  def initialize
    repository = RegisterSourcesBods::Repository.new(index: RegisterSourcesBods::Config::ELASTICSEARCH_INDEX)
    super(statement_repository: repository)
  end
end
