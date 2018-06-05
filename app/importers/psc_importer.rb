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

    Parallel.each(queue, in_threads: Concurrent.processor_count) do |line|
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

    case record.data.kind
    when 'totals#persons-of-significant-control-snapshot'
      :ignore
    when 'persons-with-significant-control-statement', 'super-secure-person-with-significant-control', 'exemptions'
      child_entity = child_entity!(record.company_number)

      statement!(child_entity, record.data)
    when /(individual|corporate-entity|legal-person)-person-with-significant-control/
      begin
        child_entity = child_entity!(record.company_number)

        parent_entity = parent_entity!(record.data)

        relationship!(child_entity, parent_entity, record.data)
      rescue PotentiallyBadEntityMergeDetectedAndStopped => ex
        Rails.logger.warn "[PSC import] Failed to handle a required entity merge as a potentially bad merge has been detected and stopped: #{ex.message} - will not complete the import of this line: #{line}"
      end
    else
      raise "unexpected kind: #{record.data.kind}"
    end
  end

  def child_entity!(company_number)
    attributes = {
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => company_number,
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'gb',
      company_number: company_number,
    }

    # If an entity already exists for this PSC record, and it contains an OC
    # identifier, then we can short circuit and use this entity directly
    # (saving us having to resolve against the OC API again, etc.)
    #
    # This does mean we won't pull in the latest info from OC, which is a
    # separate issue we can solve later.

    new_or_updated_child_entity = -> do
      entity = Entity.new(attributes)
      @entity_resolver.resolve!(entity)
      entity
        .tap(&method(:upsert_entity_and_handle_dups))
        .tap(&method(:index_entity))
    end

    entity = Entity.with_identifiers(attributes[:identifiers]).first
    if entity && entity.oc_identifier.present?
      entity
    else
      new_or_updated_child_entity.call
    end
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

    entity
      .tap(&method(:upsert_entity_and_handle_dups))
      .tap(&method(:index_entity))
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
      ended_date: data.ceased_on.presence,
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
      ended_date: data.ceased_on.presence,
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
        date: Date.parse(exemption.items.map(&:exempt_from).max),
      }
    end
  end

  ADDRESS_KEYS = %i[premises address_line_1 address_line_2 locality region postal_code].freeze

  def address_string(address)
    address.to_h.values_at(*ADDRESS_KEYS).map(&:presence).compact.join(', ')
  end

  NAME_KEYS = %i[forename middle_name surname].freeze

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

  def index_entity(entity)
    IndexEntityService.new(entity).index
  end

  def upsert_entity_and_handle_dups(entity)
    entity.upsert
  rescue DuplicateEntitiesDetected => ex
    handle_duplicate_entities!(ex.criteria)
    retry
  end

  def handle_duplicate_entities!(criteria)
    entities = criteria.entries

    to_remove, to_keep = EntityMergeDecider.new(*entities).call

    Rails.logger.info "[PSC import] Duplicate entities detected for selector: #{criteria.selector} - attempting to merge entity A into entity B. A = ID: #{to_remove._id}, name: #{to_remove.name}, identifiers: #{to_remove.identifiers}; B = ID: #{to_keep._id}, name: #{to_keep.name}, identifiers: #{to_keep.identifiers};"

    EntityMerger.new(to_remove, to_keep).call
  end
end
