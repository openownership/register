module ActsAsEntity
  extend ActiveSupport::Concern

  module Types
    NATURAL_PERSON = "natural-person".freeze
    LEGAL_ENTITY = "legal-entity".freeze
  end

  included do
    include Mongoid::Document

    field :type, type: String

    field :name, type: String
    field :address, type: String

    field :nationality, type: String
    field :country_of_residence, type: String
    field :dob, type: ISO8601::Date

    field :jurisdiction_code, type: String
    field :company_number, type: String
    field :incorporation_date, type: Date
    field :dissolution_date, type: Date
    field :company_type, type: String
  end

  def natural_person?
    type == Types::NATURAL_PERSON
  end

  def legal_entity?
    type == Types::LEGAL_ENTITY
  end

  def country
    if natural_person?
      return unless nationality
      ISO3166::Country[nationality]
    else
      return unless jurisdiction_code
      code, = jurisdiction_code.split('_')
      ISO3166::Country[code]
    end
  end

  def country_subdivision
    return if natural_person?
    return unless country
    _, code = jurisdiction_code.split('_')
    return unless code
    country.subdivisions[code.upcase]
  end

  def country_code
    country.try(:alpha2)
  end
end