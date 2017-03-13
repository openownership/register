require 'json'
require 'parallel'

class PscImporter
  def initialize(opencorporates_client: OpencorporatesClient.new, entity_resolver: EntityResolver.new)
    @opencorporates_client = opencorporates_client

    @entity_resolver = entity_resolver
  end

  def parse(file, document_id:)
    @document_id = document_id

    queue = SizedQueue.new(100)

    Thread.abort_on_exception = true
    Thread.new do
      file.each_line do |line|
        queue << line
      end

      queue << Parallel::Stop
    end

    Parallel.each(queue, in_threads: 20) do |line|
      Mongoid.default_client.reconnect

      process(line)
    end
  end

  private

  def process(line)
    record = JSON.parse(line, symbolize_names: true, object_class: OpenStruct)

    case record.data.kind
    when 'totals#persons-of-significant-control-snapshot',
         'persons-with-significant-control-statement',
         'super-secure-person-with-significant-control',
         'exemptions'
      :ignore
    when /(individual|corporate-entity|legal-person)-person-with-significant-control/
      child_entity = @entity_resolver.resolve!(jurisdiction_code: 'gb', identifier: record.company_number, name: nil)

      parent_entity = parent_entity!(record.data)

      relationship!(child_entity, parent_entity, record.data)
    else
      raise "unexpected kind: #{record.data.kind}"
    end
  end

  def parent_entity!(data)
    if data.kind.start_with?('corporate-entity-person')
      country = data.identification.country_registered

      unless country.nil?
        jurisdiction_code = @opencorporates_client.get_jurisdiction_code(country)

        unless jurisdiction_code.nil?
          identifier = data.identification.registration_number

          name = data.name

          entity = @entity_resolver.resolve!(jurisdiction_code: jurisdiction_code, identifier: identifier, name: name)

          return entity unless entity.nil?
        end
      end
    end

    entity_with_document_id!(data)
  end

  def entity_with_document_id!(data)
    attributes = {
      identifiers: [
        {
          _id: {
            document_id: @document_id,
            link: data.links.self
          }
        }
      ],
      type: entity_type(data),
      name: data.name_elements.presence && name_string(data.name_elements) || data.name,
      nationality: country_from_nationality(data.nationality).try(:alpha2),
      address: data.address.presence && address_string(data.address),
      country_of_residence: data.country_of_residence.presence,
      dob_year: data.date_of_birth && data.date_of_birth.year,
      dob_month: data.date_of_birth && data.date_of_birth.month,
      dob_day: data.date_of_birth && data.date_of_birth.day
    }

    Entity.new(attributes).tap(&:upsert)
  end

  def relationship!(child_entity, parent_entity, data)
    attributes = {
      _id: {
        document_id: @document_id,
        link: data.links.self
      },
      source: parent_entity,
      target: child_entity,
      interests: data.natures_of_control
    }

    Relationship.new(attributes).upsert
  end

  ADDRESS_KEYS = [:premises, :address_line_1, :address_line_2, :locality, :region, :postal_code].freeze

  def address_string(address)
    address.to_h.values_at(*ADDRESS_KEYS).map(&:presence).compact.join(', ')
  end

  NAME_KEYS = [:forename, :middle_name, :surname].freeze

  def name_string(name_elements)
    name_elements.to_h.values_at(*NAME_KEYS).map(&:presence).compact.join(' ')
  end

  def country_from_nationality(nationality)
    countries = ISO3166::Country.find_all_countries_by_nationality(nationality)
    return if countries.count > 1 # too ambiguous
    countries[0]
  end

  def entity_type(data)
    return Entity::Types::NATURAL_PERSON if data.kind == 'individual-person-with-significant-control'

    Entity::Types::LEGAL_ENTITY
  end
end
