# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

class DataSource < Dry::Struct
  module Types
    include Dry.Types()
  end

  DataSourceTypes = Types::String.enum(
    'selfDeclaration',
    'officialRegister',
    'thirdParty',
    'primaryResearch',
    'verified'
  )

  transform_keys(&:to_sym)

  attribute :id, Types::String # Mongo BSON ID as string
  attribute? :_slugs, Types::Array(Types::String)
  attribute? :created_at, Types::String
  attribute? :current_statistic_types, Types::Array(Types::String)
  attribute? :document_id, Types::String.optional
  attribute :name, Types::String
  attribute? :overview, Types::String.optional # localize: true
  attribute? :data_availability, Types::String.optional # localize: true
  attribute? :timeline_url, Types::String.optional
  attribute? :types, Types::Array(DataSourceTypes)
  attribute? :updated_at, Types::String
  attribute? :url, Types::String.optional

  def slug
    _slugs[0]
  end
end
