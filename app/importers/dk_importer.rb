# NOTE: some of the logic in this importer is based on the OC script:
# https://gist.github.com/skenaja/cf843d127e8937b5f79fa6d0e81d1543

class DkImporter
  attr_accessor :source_url, :source_name, :document_id, :retrieved_at

  def initialize(entity_resolver: EntityResolver.new)
    @entity_resolver = entity_resolver
  end

  def process_records(records)
    records.each { |r| process(r) }
  end

  def process(record)
    # A record here conforms to the `Vrdeltagerperson` data type from the DK data source

    return if record['fejlRegistreret'] # ignore if errors discovered

    return unless record['enhedstype'] == 'PERSON'

    relations = relations_with_real_owner_status(record)

    return if relations.blank?

    parent_entity = parent_entity!(record)

    relations.each do |relation|
      child_entity = child_entity!(relation)

      relationship!(child_entity, parent_entity, record, relation)
    end
  end

  private

  def parent_entity!(record)
    latest_address = most_recent(record['beliggenhedsadresse'])

    entity = Entity.new(
      identifiers: [
        {
          'document_id' => document_id,
          'beneficial_owner_id' => record['enhedsNummer'].to_s,
        },
      ],
      type: Entity::Types::NATURAL_PERSON,
      name: most_recent(record['navne'])['navn'],
      country_of_residence: latest_address.try { |a| a['landekode'] },
      address: build_address(most_recent(record['beliggenhedsadresse'])),
    )

    entity
      .tap(&:upsert)
      .tap(&method(:index_entity))
  end

  def child_entity!(relation)
    company_data = relation[:company]

    entity = Entity.new(
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => company_data['cvrNummer'].to_s,
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'dk',
      company_number: company_data['cvrNummer'].to_s,
      name: most_recent(company_data['navne'])['navn'],
    )
    @entity_resolver.resolve!(entity)

    entity
      .tap(&:upsert)
      .tap(&method(:index_entity))
  end

  def relationship!(child_entity, parent_entity, record, relation)
    attributes = {
      _id: {
        'document_id' => document_id,
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
        source_url: source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }.compact

    Relationship.new(attributes).upsert
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

      item['organisationer'].each do |o|
        o['medlemsData'].each do |md|
          md['attributter'].each do |a|
            next unless a['type'] == 'FUNKTION'

            real_owner_role = most_recent(
              a['vaerdier'].select { |v| v['vaerdi'] == 'Reel ejer' },
            )
            interests = parse_and_build_interests(md['attributter'])
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
      }
    end
  end

  def parse_and_build_interests(attributes)
    interests = []

    attributes.each do |a|
      interest_type = nil
      interest_share_min = nil
      interest_share_max = nil

      case a['type']
      when 'EJERANDEL_PROCENT'
        interest_type = 'shareholding'
        percentage_of_shares = most_recent(a['vaerdier'])['vaerdi'].to_f * 100.0
        interest_share_min, interest_share_max = percentage_range(percentage_of_shares)
      when 'EJERANDEL_STEMMERET_PROCENT'
        interest_type = 'voting-rights'
        voting_percentage = most_recent(a['vaerdier'])['vaerdi'].to_f * 100.0
        interest_share_min, interest_share_max = percentage_range(voting_percentage)
      end

      next if interest_type.blank?

      interests << {
        'type' => interest_type,
        'share_min' => interest_share_min,
        'share_max' => interest_share_max,
      }
    end

    interests
  end

  # From the data source docs:
  #
  # Legal owners are recorded in intervals and exhibited with a limit value. The displayed limit values are expressed as follows:
  #
  # 0.05:   5-9.99%
  # 0.1:    10-14.99%
  # 0.15:   15-19.99%
  # 0.2:    20-24.99%
  # 0.25:   25-33.33%
  # 0.33:   33.34-49.99%
  # 0.5:    5-66.65%
  # 0.6667: 66.66-89.99%
  # 0.9:    90-99.99%
  # 1.0:    100%
  def percentage_range(value)
    return [5.0, 9.99] if value <= 5.0
    return [10.0, 14.99] if value <= 10.0
    return [15.0, 19.99] if value <= 15.0
    return [20.0, 24.99] if value <= 20.0
    return [25.0, 33.33] if value <= 25.0
    return [33.34, 49.99] if value <= 33.33
    return [50.0, 66.65] if value <= 50.0
    return [66.66, 89.99] if value <= 66.67
    return [90.0, 99.99] if value <= 90.0
    return [100.0, 100.0] if value == 100.0
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
