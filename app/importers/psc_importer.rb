require 'oj'

class PscImporter
  attr_accessor :import, :retrieved_at

  def initialize(opencorporates_client: OpencorporatesClient.new_for_imports, entity_resolver: EntityResolver.new)
    @opencorporates_client = opencorporates_client

    @entity_resolver = entity_resolver
  end

  def process_records(raw_records)
    provenances = raw_records.map { |r| [r.id, process(r)] }.to_h
    RawDataProvenance.bulk_upsert_for_import(import, provenances)
  end

  def process(raw_record)
    record = Oj.load(raw_record.raw_data, mode: :rails)
    case record['data']['kind']
    when 'totals#persons-of-significant-control-snapshot'
      :ignore
    when 'persons-with-significant-control-statement', 'super-secure-person-with-significant-control', 'exemptions'
      child_entity = child_entity!(record['company_number'])

      statement = statement!(child_entity, record['data'])

      [child_entity, statement]
    when /(individual|corporate-entity|legal-person)-person-with-significant-control/
      begin
        child_entity = child_entity!(record['company_number'])

        parent_entity = parent_entity!(record['data'])

        relationship = relationship!(child_entity, parent_entity, record['data'])

        [child_entity, parent_entity, relationship]
      rescue PotentiallyBadEntityMergeDetectedAndStopped => e
        msg = "[#{self.class.name}] Failed to handle a required entity merge " \
              "as a potentially bad merge has been detected and stopped: " \
              "#{e.message} - will not complete the import of this raw " \
              "record: #{raw_record.id}"
        Rails.logger.warn msg
      end
    else
      raise "unexpected kind: #{record['data']['kind']}"
    end
  end

  private

  def child_entity!(company_number)
    entity = Entity.new(
      identifiers: [
        {
          'document_id' => import.data_source.document_id,
          'company_number' => company_number,
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'gb',
      company_number: company_number,
    )
    @entity_resolver.resolve!(entity)
    entity.upsert_and_merge_duplicates!
    index_entity(entity)
    entity
  end

  def parent_entity!(data)
    entity = Entity.new(
      identifiers: [
        {
          'document_id' => import.data_source.document_id,
          'link' => data['links']['self'],
        },
      ],
      address: data['address'].presence && address_string(data['address']),
    )

    case data['kind']
    when 'corporate-entity-person-with-significant-control'
      entity.assign_attributes(
        type: Entity::Types::LEGAL_ENTITY,
        name: data['name'],
      )

      jurisdiction_code = entity_jurisdiction_code(data['identification']['country_registered'])

      unless jurisdiction_code.nil?
        entity.assign_attributes(
          identifiers: [
            {
              'document_id' => import.data_source.document_id,
              'link' => data['links']['self'],
              'company_number' => data['identification']['registration_number'],
            },
          ],
          jurisdiction_code: jurisdiction_code,
          company_number: data['identification']['registration_number'],
        )
      end

      @entity_resolver.resolve!(entity)
    when 'individual-person-with-significant-control'
      entity.assign_attributes(
        type: Entity::Types::NATURAL_PERSON,
        name: (data['name_elements'].presence && name_string(data['name_elements'])) || data['name'],
        nationality: country_from_nationality(data['nationality']).try(:alpha2),
        country_of_residence: data['country_of_residence'].presence,
        dob: entity_dob(data['date_of_birth']),
      )
    when 'legal-person-person-with-significant-control'
      entity.assign_attributes(
        type: Entity::Types::LEGAL_ENTITY,
        name: data['name'],
      )
    end

    entity.upsert_and_merge_duplicates!
    index_entity(entity)
    entity
  end

  def relationship!(child_entity, parent_entity, data)
    attributes = {
      _id: {
        'document_id' => import.data_source.document_id,
        'link' => data['links']['self'],
      },
      source: parent_entity,
      target: child_entity,
      interests: data['natures_of_control'],
      sample_date: data['notified_on'].presence,
      started_date: data['notified_on'].presence,
      ended_date: data['ceased_on'].presence,
      provenance: {
        source_url: import.data_source.url,
        source_name: import.data_source.name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }

    relationship = Relationship.new(attributes)
    relationship.upsert
    relationship
  end

  def statement!(entity, data)
    attributes = {
      _id: {
        document_id: import.data_source.document_id,
        link: data['links']['self'],
      },
      entity: entity,
      ended_date: data['ceased_on'].presence,
    }

    attributes.merge!(statement_attributes(data))

    statement = Statement.new(attributes)
    statement.upsert
    statement
  end

  def statement_attributes(data)
    case data['kind']
    when 'persons-with-significant-control-statement'
      {
        type: data['statement'],
        date: Date.parse(data['notified_on']),
      }
    when 'super-secure-person-with-significant-control'
      {
        type: data['kind'],
      }
    when 'exemptions'
      exemption = data['exemptions'].values.first
      exempt_from_dates = exemption['items'].map { |item| item['exempt_from'] }

      {
        type: exemption['exemption_type'],
        date: Date.parse(exempt_from_dates.max),
      }
    end
  end

  ADDRESS_KEYS = %w[premises address_line_1 address_line_2 locality region postal_code].freeze

  def address_string(address)
    address.values_at(*ADDRESS_KEYS).map(&:presence).compact.join(', ')
  end

  NAME_KEYS = %w[forename middle_name surname].freeze

  def name_string(name_elements)
    name_elements.values_at(*NAME_KEYS).map(&:presence).compact.join(' ')
  end

  def country_from_nationality(nationality)
    countries = ISO3166::Country.find_all_countries_by_nationality(nationality)
    return if countries.count > 1 # too ambiguous

    countries[0]
  end

  def entity_dob(elements)
    return unless elements

    parts = [elements['year']]
    parts << format('%02d', elements['month']) if elements['month']
    parts << format('%02d', elements['day']) if elements['month'] && elements['day']
    ISO8601::Date.new(parts.join('-'))
  end

  def entity_jurisdiction_code(country)
    return if country.nil?

    @opencorporates_client.get_jurisdiction_code(country)
  end

  def index_entity(entity)
    IndexEntityService.new(entity).index
  end
end
