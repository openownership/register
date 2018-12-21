class SkImporter
  attr_accessor :source_url, :source_name, :document_id, :retrieved_at

  def initialize(entity_resolver: EntityResolver.new)
    @entity_resolver = entity_resolver
  end

  def process_records(records)
    records.each { |r| process(r) }
  end

  def process(record)
    return unless slovakian_address?(record['PartneriVerejnehoSektora'].first['Adresa'])

    child_entity = child_entity!(record)

    return if child_entity.nil?

    record['KonecniUzivateliaVyhod'].each do |item|
      next unless item['PlatnostDo'].nil?

      parent_entity = parent_entity!(item)

      relationship!(child_entity, parent_entity, item)
    end
  end

  private

  def child_entity!(record)
    item = record['PartneriVerejnehoSektora'].find { |p| p['PlatnostDo'].nil? }

    # See OO-251
    if item['ObchodneMeno'].nil?
      Rails.logger.warn("[#{self.class.name}] record Id: #{record['Id']} has a child entity (PartneriVerejnehoSektora) with no company name (ObchodneMeno)")
      return
    end

    entity = Entity.new(
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => item['Ico'],
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'sk',
      company_number: item['Ico'],
      name: item['ObchodneMeno'].strip,
      address: address_string(item['Adresa']),
    )
    @entity_resolver.resolve!(entity)

    entity.tap(&:upsert)
  end

  def parent_entity!(item)
    attributes = {
      identifiers: [
        {
          'document_id' => document_id,
          'beneficial_owner_id' => item['Id'],
        },
      ],
      type: Entity::Types::NATURAL_PERSON,
      name: name_string(item),
      nationality: country_from_nationality(item).try(:alpha2),
      address: item['Adresa'].presence && address_string(item['Adresa']),
      dob: entity_dob(item['DatumNarodenia']),
    }

    Entity.new(attributes).tap(&:upsert)
  end

  def relationship!(child_entity, parent_entity, item)
    attributes = {
      _id: {
        'document_id' => document_id,
        'beneficial_owner_id' => item['Id'],
      },
      source: parent_entity,
      target: child_entity,
      sample_date: Date.parse(item['PlatnostOd']).to_s,
      provenance: {
        source_url: source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }

    Relationship.new(attributes).upsert
  end

  def slovakian_address?(address)
    address['Psc'].present? && address['Psc'].strip =~ /^\d{3} ?\d{2}$/
  end

  def address_string(address)
    first_line = [address['OrientacneCislo'], address['MenoUlice']].map(&:presence).compact.join(' ')

    [first_line, address['Mesto'], address['Psc']].map(&:presence).compact.map(&:strip).join(', ')
  end

  def name_string(item)
    item.values_at('Meno', 'Priezvisko').map(&:presence).compact.join(' ')
  end

  def country_from_nationality(item)
    ISO3166::Country.find_country_by_number(item['StatnaPrislusnost']['StatistickyKod'])
  end

  def entity_dob(timestamp)
    return unless timestamp
    ISO8601::Date.new(timestamp.split('T')[0])
  end
end
