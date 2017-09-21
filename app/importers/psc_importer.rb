require 'json'
require 'parallel'

class PscImporter
  attr_accessor :source_url, :source_name, :document_id, :retrieved_at

  def initialize(opencorporates_client: OpencorporatesClient.new, entity_resolver: EntityResolver.new)
    @opencorporates_client = opencorporates_client

    @entity_resolver = entity_resolver
  end

  def parse(file)
    queue = SizedQueue.new(100)

    Thread.abort_on_exception = true
    Thread.new do
      file.each_line do |line|
        queue << line
      end

      queue << Parallel::Stop
    end

    Parallel.each(queue, in_threads: 20) do |line|
      begin
        process(line)
      rescue Timeout::Error
        retry
      end
    end
  end

  private

  def process(line)
    record = JSON.parse(line, symbolize_names: true, object_class: OpenStruct)

    return if record.data.ceased_on.present?

    case record.data.kind
    when 'totals#persons-of-significant-control-snapshot'
      :ignore
    when 'persons-with-significant-control-statement', 'super-secure-person-with-significant-control', 'exemptions'
      child_entity = child_entity!(record.company_number)

      statement!(child_entity, record.data)
    when /(individual|corporate-entity|legal-person)-person-with-significant-control/
      child_entity = child_entity!(record.company_number)

      parent_entity = parent_entity!(record.data)

      relationship!(child_entity, parent_entity, record.data)
    else
      raise "unexpected kind: #{record.data.kind}"
    end
  end

  def child_entity!(company_number)
    entity = Entity.new(
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => company_number,
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'gb',
      company_number: company_number,
    )
    @entity_resolver.resolve!(entity)
    entity.tap(&:upsert)
  end

  def parent_entity!(data)
    entity = Entity.new(
      identifiers: [
        {
          'document_id' => document_id,
          'link' => data.links.self,
        },
      ],
      address: data.address.presence && address_string(data.address),
    )

    case data.kind
    when 'corporate-entity-person-with-significant-control'
      entity.assign_attributes(
        type: Entity::Types::LEGAL_ENTITY,
        name: data.name,
      )

      country = data.identification.country_registered

      unless country.nil?
        jurisdiction_code = @opencorporates_client.get_jurisdiction_code(country)

        unless jurisdiction_code.nil?
          entity.assign_attributes(
            jurisdiction_code: jurisdiction_code,
            company_number: data.identification.registration_number,
          )
          @entity_resolver.resolve!(entity)
        end
      end
    when 'individual-person-with-significant-control'
      entity.assign_attributes(
        type: Entity::Types::NATURAL_PERSON,
        name: data.name_elements.presence && name_string(data.name_elements) || data.name,
        nationality: country_from_nationality(data.nationality).try(:alpha2),
        country_of_residence: data.country_of_residence.presence,
        dob: entity_dob(data.date_of_birth),
      )
    when 'legal-person-person-with-significant-control'
      entity.assign_attributes(
        type: Entity::Types::LEGAL_ENTITY,
        name: data.name,
      )
    end

    entity.tap(&:upsert)
  end

  def relationship!(child_entity, parent_entity, data)
    attributes = {
      _id: {
        'document_id' => document_id,
        'link' => data.links.self,
      },
      source: parent_entity,
      target: child_entity,
      interests: data.natures_of_control,
      sample_date: data.notified_on.presence,
      provenance: {
        source_url: source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }

    Relationship.new(attributes).upsert
  end

  def statement!(entity, data)
    attributes = {
      _id: {
        document_id: document_id,
        link: data.links.self,
      },
      entity: entity,
    }

    attributes.merge!(statement_attributes(data))

    Statement.new(attributes).upsert
  end

  def statement_attributes(data)
    case data.kind
    when 'persons-with-significant-control-statement'
      {
        type: data.statement,
        date: Date.parse(data.notified_on),
      }
    when 'super-secure-person-with-significant-control'
      {
        type: data.kind,
      }
    when 'exemptions'
      exemption = data.exemptions.to_h.values.first

      {
        type: exemption.exemption_type,
        date: Date.parse(exemption.items.map(&:exempt_from).sort.last),
      }
    end
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

  def entity_dob(elements)
    return unless elements
    parts = [elements.year]
    parts << format('%02d', elements.month) if elements.month
    parts << format('%02d', elements.day) if elements.month && elements.day
    ISO8601::Date.new(parts.join('-'))
  end
end
