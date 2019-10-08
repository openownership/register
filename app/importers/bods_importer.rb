class BodsImporter
  attr_accessor :source_url, :source_name, :document_id, :retrieved_at

  def initialize(
    opencorporates_client: OpencorporatesClient.new_for_imports,
    entity_resolver: EntityResolver.new,
    company_number_extractor: nil
  )
    @opencorporates_client = opencorporates_client
    @entity_resolver = entity_resolver
    @company_number_extractor = company_number_extractor
  end

  def process_records(records)
    records.each { |r| process(r) }
  end

  def process(record)
    raise "Missing statementID in: #{record}" if record['statementID'].blank?
    raise "Missing statementType in statement: #{record['statementID']}" if record['statementType'].blank?

    case record["statementType"]
    when 'entityStatement'
      legal_entity!(record)
    when 'personStatement'
      natural_person!(record)
    when 'ownershipOrControlStatement'
      ownership!(record)
    else
      raise "Unknown statement type: #{record['statementType']} in statement: #{record['statementID']}"
    end
  end

  private

  def legal_entity!(record)
    raise "Missing entityType in statement: #{record['statementID']}" if record['entityType'].blank?

    entity = new_or_existing_legal_entity(record)
    @entity_resolver.resolve!(entity) if entity.jurisdiction_code.present?
    entity.save!
    index_entity(entity)
  rescue Mongo::Error::OperationFailure => e
    skip_saving_duplicate_identifiers(entity, e)
  end

  def natural_person!(record)
    return if Entity.where('identifiers.statement_id' => record['statementID']).exists?

    entity = Entity.new(
      identifiers: [{
        'document_id' => document_id,
        'statement_id' => record['statementID'],
      }] + entity_identifiers(record['identifiers']),
      type: Entity::Types::NATURAL_PERSON,
      name: first_individual_name(record['names']),
      nationality: country_code_from_nationalities(record['nationalities']),
      country_of_residence: record.dig('placeOfResidence', 'country'),
      dob: exact_iso8601_date(record['birthDate']),
      address: first_address_of_type('service', record['addresses']),
    )
    entity.save!

    index_entity(entity)
  rescue Mongo::Error::OperationFailure => e
    skip_saving_duplicate_identifiers(entity, e)
  end

  def ownership!(record)
    raise "Missing subject in statement: #{record['statementID']}" if record['subject'].blank?
    raise "Missing interestedParty in statement: #{record['statementID']}" if record['interestedParty'].blank?

    return if relationship_or_statement_exists?(record['statementID'])

    child, parent = nil
    begin
      child = child_entity!(record)
      parent = parent_entity!(record)
    rescue Mongoid::Errors::DocumentNotFound
      enqueue_retry(record)
      return
    end

    if parent.blank?
      statement!(child, record)
    else
      relationship!(child, parent, record)
    end
  end

  def statement!(child, record)
    statement = Statement.new(
      _id: {
        'document_id' => document_id,
        'statement_id' => record["statementID"],
      },
      type: record.dig('interestedParty', 'unspecified', 'reason'),
      date: exact_date(record['statementDate']),
      entity: child,
    )
    statement.save!
  rescue Mongo::Error::OperationFailure => e
    # Make sure it's a duplicate key error "E11000 duplicate key error collection"
    raise unless e.message.start_with?('E11000')
    # Make sure it's the _id that is duplicated
    raise unless Statement.where('_id' => statement._id).exists?
    # Ignore this attempt to save, the record already exists
  end

  def relationship!(child, parent, record)
    relationship = Relationship.new(
      _id: {
        'document_id' => document_id,
        'statement_id' => record["statementID"],
      },
      sample_date: exact_iso8601_date(record['statementDate']),
      started_date: earliest_interest_start_date(record['interests']),
      ended_date: ownership_end_date(record['interests']),
      source: parent,
      target: child,
      interests: map_interests(record['interests']),
      provenance: {
        source_url: source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    )
    relationship.save!
  rescue Mongo::Error::OperationFailure => e
    # Make sure it's a duplicate key error "E11000 duplicate key error collection"
    raise unless e.message.start_with?('E11000')
    # Make sure it's the _id that is duplicated
    raise unless Relationship.where('_id' => relationship._id).exists?
    # Ignore this attempt to save, the record already exists
  end

  def relationship_or_statement_exists?(statement_id)
    Relationship.where('_id.statement_id' => statement_id).exists? || \
      Statement.where('_id.statement_id' => statement_id).exists?
  end

  def new_or_existing_legal_entity(record)
    existing = Entity.where('identifiers.statement_id' => record['statementID'])
    return existing.first unless existing.empty?

    attributes = {
      identifiers: [{
        'document_id' => document_id,
        'statement_id' => record["statementID"],
      }] + entity_identifiers(record["identifiers"]),
      type: Entity::Types::LEGAL_ENTITY,

      name: record["name"],
      incorporation_date: exact_date(record["foundingDate"]),
      dissolution_date: exact_date(record["dissolutionDate"]),
      jurisdiction_code: entity_jurisdiction_code(record['incorporatedInJurisdiction']),
      address: first_address_of_type('registered', record["addresses"]),
      company_number: @company_number_extractor.try(:extract, record['identifiers']),
    }

    Entity.new(attributes)
  end

  def skip_saving_duplicate_identifiers(entity, exception)
    # Make sure it's a duplicate key error "E11000 duplicate key error collection"
    raise unless exception.message.start_with?('E11000')
    # Make sure it's the identifiers that are duplicated
    raise unless Entity.where('identifiers' => entity.identifiers).exists?
    # Ignore this attempt to save, the record already exists
  end

  def entity_identifiers(identifiers)
    return [] if identifiers.blank?

    identifiers.map { |i| { entity_identifier_scheme(i) => i['id'] } }
  end

  def entity_identifier_scheme(identifier)
    scheme = identifier['scheme'] || identifier['schemeName']
    raise "No identifier scheme or schemeName given in #{identifier}" if scheme.blank?

    scheme
  end

  def entity_jurisdiction_code(jurisdiction)
    return if jurisdiction.blank?

    if jurisdiction['code'].present?
      jurisdiction['code'][0..1]
    elsif jurisdiction['name'].present?
      @opencorporates_client.get_jurisdiction_code(jurisdiction['name'])
    end
  end

  def first_address_of_type(type, addresses)
    return if addresses.blank?

    address = addresses.find { |a| a['type'] == type }
    address['address'] if address
  end

  def first_individual_name(names)
    return if names.blank?

    name = names.find { |a| a['type'] == 'individual' }
    name['fullName'] if name
  end

  def exact_iso8601_date(approximate_datetime)
    return if approximate_datetime.blank?

    iso_datetime = ISO8601::DateTime.new(approximate_datetime).to_date.iso8601
    ISO8601::Date.new(iso_datetime)
  end

  def exact_date(approximate_datetime)
    return if approximate_datetime.blank?

    ISO8601::DateTime.new(approximate_datetime).to_date
  end

  def country_code_from_nationalities(nationalities)
    return if nationalities.blank?

    nationality = nationalities.first
    return nationality['code'] if nationality['code'].present?
    return if nationality['name'].blank?

    country = ISO3166::Country.find_by_name(nationality['name']) # rubocop:disable Rails/DynamicFindBy
    return if country.blank?

    # Country is an array like ["ALPHA2-CODE", {country_object}]
    country.first
  end

  def index_entity(entity)
    IndexEntityService.new(entity).index
  end

  def child_entity!(record)
    no_subject_error = "No describedByEntityStatement (child entity) given " \
                       "in statement: #{record['statementID']}"
    raise no_subject_error if record['subject']['describedByEntityStatement'].blank?

    Entity.find_by('identifiers.statement_id' => record['subject']['describedByEntityStatement'])
  end

  def parent_entity!(record)
    multiple_parties_error = "More than one interestedParty specified in " \
                             "statement: #{record['statementID']}"
    raise multiple_parties_error if record['interestedParty'].keys.length > 1

    party_type, party_details = record['interestedParty'].first
    case party_type
    when 'describedByEntityStatement', 'describedByPersonStatement'
      Entity.find_by('identifiers.statement_id' => party_details)
    when 'unspecified'
      nil
    end
  end

  def enqueue_retry(record)
    raise "Cannot find dependent records for statement: #{record['statementID']} on retry" if record['retried']

    record['retried'] = true
    string = record.to_json
    chunk = ChunkHelper.to_chunk [string]
    BodsChunkImportRetryWorker.perform_async(chunk, retrieved_at, @company_number_extractor.schemes)
  end

  def earliest_interest_start_date(interests)
    return if interests.blank?

    exact_iso8601_date(interests.map { |i| i['startDate'] }.compact.min)
  end

  def latest_interest_end_date(interests)
    return if interests.blank?

    exact_iso8601_date(interests.map { |i| i['endDate'] }.compact.max)
  end

  def all_interests_ended?(interests)
    return false if interests.blank?

    interests.all? { |i| i['endDate'] }
  end

  def ownership_end_date(interests)
    return nil unless all_interests_ended?(interests)

    latest_interest_end_date(interests)
  end

  def map_interests(interests)
    return [] if interests.blank?

    interests.map do |interest|
      if interest['share'].present?
        {
          type: interest['type'],
        }.merge(map_share(interest['share']))
      else
        interest['type']
      end
    end
  end

  def map_share(share)
    if share['exact']
      {
        share_min: share['exact'],
        share_max: share['exact'],
      }
    else
      {
        share_min: share['minimum'],
        share_max: share['maximum'],
        exclusive_min: share['exclusiveMin'].nil? ? false : share['exclusiveMin'],
        exclusive_max: share['exclusiveMax'].nil? ? true : share['exclusiveMax'],
      }
    end
  end
end
