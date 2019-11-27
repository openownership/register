# NOTE: some of the logic in this importer is based on the OC script:
# https://gist.github.com/skenaja/cf843d127e8937b5f79fa6d0e81d1543

class DkImporter
  attr_accessor :import, :retrieved_at

  def initialize(entity_resolver: EntityResolver.new)
    @entity_resolver = entity_resolver
  end

  def process_records(raw_records)
    provenances = raw_records.map { |r| [r.id, process(r)] }.to_h
    RawDataProvenance.bulk_upsert_for_import(import, provenances)
  end

  def process(raw_record)
    record = Oj.load(raw_record.raw_data, mode: :rails)

    # A record here conforms to the `Vrdeltagerperson` data type from the DK data source

    return if record['fejlRegistreret'] # ignore if errors discovered

    return unless record['enhedstype'] == 'PERSON'

    relations = relations_with_real_owner_status(record)

    return if relations.blank?

    parent_entity = parent_entity!(record)

    child_entities = []
    relationships = []
    relations.each do |relation|
      child_entity = child_entity!(relation)
      child_entities << child_entity
      relationships << relationship!(child_entity, parent_entity, record, relation)
    end

    [parent_entity] + child_entities + relationships
  end

  private

  def parent_entity!(record)
    latest_address = most_recent(record['beliggenhedsadresse'])

    entity = Entity.new(
      identifiers: [
        {
          'document_id' => import.data_source.document_id,
          'beneficial_owner_id' => record['enhedsNummer'].to_s,
        },
      ],
      type: Entity::Types::NATURAL_PERSON,
      name: most_recent(record['navne'])['navn'],
      country_of_residence: latest_address.try { |a| a['landekode'] },
      address: build_address(most_recent(record['beliggenhedsadresse'])),
    )

    entity.upsert
    index_entity(entity)
    entity
  end

  def child_entity!(relation)
    company_data = relation[:company]

    entity = Entity.new(
      identifiers: [
        {
          'document_id' => import.data_source.document_id,
          'company_number' => company_data['cvrNummer'].to_s,
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'dk',
      company_number: company_data['cvrNummer'].to_s,
      name: most_recent(company_data['navne'])['navn'],
    )
    @entity_resolver.resolve!(entity)

    entity.upsert
    index_entity(entity)
    entity
  end

  def relationship!(child_entity, parent_entity, record, relation)
    attributes = {
      _id: {
        'document_id' => import.data_source.document_id,
        'beneficial_owner_id' => record['enhedsNummer'].to_s,
        'company_number' => relation[:company]['cvrNummer'].to_s,
      },
      source: parent_entity,
      target: child_entity,
      interests: relation[:interests],
      started_date: relation[:start_date].presence,
      ended_date: relation[:end_date].presence,
      sample_date: relation[:last_updated].present? ? Date.parse(relation[:last_updated]).to_s : nil,
      provenance: {
        source_url: import.data_source.url,
        source_name: import.data_source.name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
      is_indirect: relation[:is_indirect],
    }.compact

    relationship = Relationship.new(attributes)
    relationship.upsert
    relationship
  end

  def index_entity(entity)
    IndexEntityService.new(entity).index
  end

  def most_recent(items)
    return unless items.all?

    sort_by_period(items).first
  end

  def sort_by_period(items)
    items.sort do |x, y|
      # Convert to strings to handle `nil` values
      y['periode']['gyldigFra'].to_s <=> x['periode']['gyldigFra'].to_s
    end
  end

  def relations_with_real_owner_status(record)
    record['virksomhedSummariskRelation'].each_with_object([]) do |item, acc|
      next if item['virksomhed']['fejlRegistreret'] # ignore if errors discovered

      real_owner_role = nil
      interests = []
      is_indirect = false

      item['organisationer'].each do |o|
        o['medlemsData'].each do |md|
          md['attributter'].each do |a|
            next unless a['type'] == 'FUNKTION'

            real_owner_role = most_recent(
              a['vaerdier'].select { |v| v['vaerdi'] == 'Reel ejer' },
            )
            interests = parse_and_build_interests(md['attributter'])
            is_indirect = indirect?(md['attributter'])
          end
        end

        break if real_owner_role.present?
      end

      next if real_owner_role.blank?

      acc << {
        last_updated: real_owner_role['sidstOpdateret'],
        start_date: real_owner_role['periode']['gyldigFra'],
        end_date: real_owner_role['periode']['gyldigTil'],
        company: item['virksomhed'],
        interests: interests,
        is_indirect: is_indirect,
      }
    end
  end

  def parse_and_build_interests(attributes)
    interests = []

    attributes.each do |a|
      interest_type = nil

      case a['type']
      when 'EJERANDEL_PROCENT'
        interest_type = 'shareholding'
      when 'EJERANDEL_STEMMERET_PROCENT'
        interest_type = 'voting-rights'
      end

      next if interest_type.blank?

      share_percentage = most_recent(a['vaerdier'])['vaerdi'].to_f * 100.0

      interests << {
        'type' => interest_type,
        'share_min' => share_percentage,
        'share_max' => share_percentage,
      }
    end

    interests
  end

  def indirect?(attributes)
    special_ownership = attributes.find { |a| a['type'] == 'SÆRLIGE_EJERFORHOLD' }
    return false if special_ownership.blank?

    most_recent(special_ownership['vaerdier'])['vaerdi'] == 'Har indirekte besiddelser'
  end

  def build_address(data)
    return if data.blank?

    if data['fritekst']
      data['fritekst']
    else
      co_name = "c/o #{data['conavn']}" if data['conavn']

      street_numbers = data.values_at('husnummerFra', 'husnummerTil').compact.join('-')

      street_address_excl_floor = [
        data['vejnavn'].try(:strip).presence,
        street_numbers,
      ].compact.map(&:strip).map(&:presence).compact.join(' ')

      street_address_excl_postbox = [
        street_address_excl_floor,
        data['etage'].try(:strip).presence,
      ].compact.join(', ')

      [
        co_name,
        street_address_excl_postbox,
        data['postboks'].try(:strip).presence && "Postboks #{data['postboks']}",
        data['postdistrikt'].try(:strip).presence,
        data['postnummer'].try(:to_s),
      ].compact.join(', ')
    end
  end
end
