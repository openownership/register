require 'xxhash'

class BodsMapper
  extend Memoist

  def self.instance
    @instance ||= new
  end

  SOURCE_TYPES_MAP = {
    'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])' => %w[officialRegister],
    'OpenOwnership Register' => %w[thirdParty selfDeclaration],
    'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)' => %w[officialRegister],
    'UK PSC Register' => %w[officialRegister],
  }.freeze

  SOURCE_NAMES_MAP = {
    'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])' => 'DK Centrale Virksomhedsregister',
    'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)' => 'SK Register Partnerov Verejného Sektora',
    'UK PSC Register' => 'GB Persons Of Significant Control Register',
  }.freeze

  DOCUMENT_IDS_MAP = {
    'Denmark CVR' => 'DK Centrale Virksomhedsregister',
    'Slovakia PSP Register' => 'SK Register Partnerov Verejného Sektora',
    'GB PSC Snapshot' => 'GB Persons Of Significant Control Register',
  }.freeze

  REASONS_FOR_UNKNOWN_PERSON_STATEMENT = %w[
    psc-contacted-but-no-response
    psc-contacted-but-no-response-partnership
    restrictions-notice-issued-to-psc
    restrictions-notice-issued-to-psc-partnership
    psc-exists-but-not-identified
    psc-exists-but-not-identified-partnership
    psc-details-not-confirmed
    psc-has-failed-to-confirm-changed-details
    psc-details-not-confirmed-partnership
    psc-has-failed-to-confirm-changed-details-partnership
    super-secure-person-with-significant-control
  ].freeze

  ID_PREFIX = 'openownership-register-'.freeze

  # See: https://org-id.guide
  # The keys are jurisdiction_code-document_id => [org-id scheme code, org-id scheme name]
  # We use a combined key because we only trust sources to have valid ids for
  # their own local companies, e.g. GB companies from the PSC register, we don't
  # declare 'official' identifiers from unofficial sources.
  LEGAL_ENTITY_ORG_ID_SCHEMES = {
    'gb-GB PSC Snapshot' => ['GB-COH', 'Companies House'],
    'dk-Denmark CVR' => ['DK-CVR', 'Danish Central Business Register'],
    'sk-Slovakia PSP Register' => ['SK-ORSR', 'Ministry of Justice Business Register'],
    'ua-Ukraine EDR' => ['UA-EDR', 'United State Register'],
  }.freeze

  # These do not conform to the BODS schema for natural persons, but we've
  # released data with them, so for compatibility we continue to include them.
  # Format: document_id => scheme code
  HISTORICAL_PERSON_ID_SCHEMES = {
    'Denmark CVR' => 'MISC-Denmark CVR',
    'Slovakia PSP Register' => 'MISC-Slovakia PSP Register',
  }.freeze

  def statement_id(obj)
    case obj
    when Entity
      return nil unless generates_statement?(obj)

      ID_PREFIX + hash("openownership-register/entity/#{obj.id}/#{obj.self_updated_at}")
    when Relationship
      things_that_make_relationship_statements_unique = {
        id: obj.id,
        updated_at: obj.updated_at,
        source_id: statement_id(obj.source),
        target_id: statement_id(obj.target),
      }
      ID_PREFIX + hash(things_that_make_relationship_statements_unique.to_json)
    when Statement
      things_that_make_psc_statement_statements_unique = {
        id: obj.id,
        updated_at: obj.updated_at,
        entity_id: statement_id(obj.entity),
      }
      ID_PREFIX + hash(things_that_make_psc_statement_statements_unique.to_json)
    else
      raise "Unexpected object for statement_id - class: #{obj.class.name}, obj: #{obj.inspect}"
    end
  end

  def generates_statement?(entity)
    return true unless entity.respond_to? :unknown_reason_code

    REASONS_FOR_UNKNOWN_PERSON_STATEMENT.include?(entity.unknown_reason_code)
  end

  def entity_statement(legal_entity)
    {
      statementID: statement_id(legal_entity),
      statementType: 'entityStatement',
      statementDate: nil,
      entityType: es_entity_type(legal_entity),
      missingInfoReason: nil,
      name: legal_entity.name,
      alternateNames: nil,
      incorporatedInJurisdiction: es_jurisdiction(legal_entity),
      identifiers: map_identifiers(legal_entity),
      foundingDate: legal_entity.incorporation_date.try(:iso8601),
      dissolutionDate: legal_entity.dissolution_date.try(:iso8601),
      addresses: es_addresses(legal_entity),
      uri: nil,
      replacesStatements: nil,
      source: nil,
      annotations: nil,
    }.compact
  end

  def person_statement(natural_person)
    return unknown_person_statement(natural_person) if natural_person.is_a? UnknownPersonsEntity

    {
      statementID: statement_id(natural_person),
      statementType: 'personStatement',
      statementDate: nil,
      personType: 'knownPerson',
      missingInfoReason: nil,
      names: ps_names(natural_person),
      identifiers: map_identifiers(natural_person),
      nationalities: ps_nationalities(natural_person),
      placeOfBirth: nil,
      birthDate: natural_person.dob.try(:to_s),
      deathDate: nil,
      placeOfResidence: nil,
      addresses: ps_addresses(natural_person),
      pepStatus: nil,
      source: nil,
      annotations: nil,
      replacesStatements: nil,
    }.compact
  end

  def ownership_or_control_statement(relationship)
    {
      statementID: statement_id(relationship),
      statementType: 'ownershipOrControlStatement',
      statementDate: relationship.sample_date.try(:to_s),
      subject: ocs_subject(relationship),
      interestedParty: ocs_interested_party(relationship),
      interests: ocs_interests(relationship),
      source: ocs_source(relationship),
      annotations: nil,
      replacesStatements: nil,
    }.compact
  end

  def hash(data)
    XXhash.xxh64(data).to_s
  end

  private

  def unknown_person_statement(unknown_person)
    {
      statementID: statement_id(unknown_person),
      statementType: 'personStatement',
      statementDate: nil,
      personType: unknown_ps_person_type(unknown_person),
      missingInfoReason: unknown_person.unknown_reason,
      names: [],
      identifiers: [],
      nationalities: [],
      placeOfBirth: nil,
      birthDate: nil,
      deathDate: nil,
      placeOfResidence: nil,
      addresses: [],
      pepStatus: nil,
      source: nil,
      annotations: nil,
      replacesStatements: nil,
    }.compact
  end

  def map_identifiers(entity)
    identifiers = entity.identifiers.flat_map do |identifier|
      next opencorporates_identifier(identifier) if entity.oc_identifier? identifier
      next psc_self_link_identifiers(identifier) if entity.legal_entity? && identifier['link']

      scheme, scheme_name = identifier_scheme(identifier, entity)
      scheme_name = identifier_scheme_name(identifier) if scheme.blank?

      next if scheme.blank? && scheme_name.blank?

      bods_identifiers = [
        {
          scheme: scheme,
          schemeName: scheme_name,
          id: identifier_id(identifier, scheme).presence.try(:to_s),
          uri: identifier['uri'],
        }.compact,
      ]

      # These do not conform to the BODS schema, but we've released data with
      # them, so for compatibility we continue to include them.
      if entity.natural_person? && HISTORICAL_PERSON_ID_SCHEMES.key?(identifier['document_id'])
        bods_identifiers << {
          scheme: HISTORICAL_PERSON_ID_SCHEMES[identifier['document_id']],
          schemeName: 'Not a valid Org-Id scheme, provided for backwards compatibility',
          id: identifier['beneficial_owner_id'].to_s,
        }
      end

      bods_identifiers
    end
    identifiers << register_identifier(entity)
    identifiers.compact.uniq
  end

  def identifier_scheme(identifier, entity)
    return [identifier['scheme'], identifier['scheme_name']] if identifier['scheme']

    return unless entity.legal_entity?

    key = "#{entity.jurisdiction_code}-#{identifier['document_id']}"
    LEGAL_ENTITY_ORG_ID_SCHEMES[key]
  end

  def identifier_scheme_name(identifier)
    return identifier['scheme_name'] if identifier['scheme_name']

    DOCUMENT_IDS_MAP.fetch(identifier['document_id'], identifier['document_id'])
  end

  def identifier_id(identifier, scheme)
    # Pass through existing BODS ids
    return identifier['id'] if identifier['id']

    # If we've got a scheme, we're an official identifier so only need a single
    # value from one of these fields
    return identifier['company_number'] || identifier['beneficial_owner_id'] if scheme

    # Only from the UK PSC register, and here only for people - companies are
    # dealt with separately.
    return identifier['link'] if identifier['link']
    # These are always unique on their own
    return identifier['statement_id'] if identifier['statement_id']

    # These remaining ones (if not caught above) have to be combined with each
    # other to make things fully unique.
    id_parts = [
      identifier['company_number'],
      identifier['beneficial_owner_id'],
      identifier['name'],
    ].compact

    id_parts.join('-')
  end

  def opencorporates_identifier(identifier)
    jurisdiction = identifier['jurisdiction_code']
    number = identifier['company_number']
    oc_url = "https://opencorporates.com/companies/#{jurisdiction}/#{number}"
    {
      schemeName: "OpenCorporates",
      id: oc_url,
      uri: oc_url,
    }
  end

  # When we import PSC data containing RLEs (intermediate company owners) we
  # give them a weird three-part identifier including their company number and
  # the original identifier from the data called a "self link". When we output
  # this we want to output two BODS identifiers, one for the link and one for the
  # company number. This allows us to a) link the statement back to the specific
  # parts of the PSC data it came from and b) share the company number we
  # figured out from an OC lookup, but make the provenance clearer.
  def psc_self_link_identifiers(identifier)
    scheme_name = DOCUMENT_IDS_MAP[identifier['document_id']]
    identifiers = [
      {
        schemeName: scheme_name,
        id: identifier['link'],
      },
    ]
    if identifier['company_number'].present?
      identifiers << {
        # These should not be compared to self links, so we give them a
        # different scheme name
        schemeName: "#{scheme_name} - Registration numbers",
        id: identifier['company_number'],
      }
    end
    identifiers
  end

  def register_identifier(entity)
    url = Rails.application.routes.url_helpers.entity_url(entity)
    {
      schemeName: 'OpenOwnership Register',
      id: url,
      uri: url,
    }
  end

  def es_entity_type(_legal_entity)
    'registeredEntity' # This probably depends on source?
  end

  def es_addresses(legal_entity)
    return nil if legal_entity.address.blank?

    [
      {
        type: 'registered',
        address: legal_entity.address,
        country: legal_entity.country_code,
      }.compact,
    ]
  end

  def es_jurisdiction(legal_entity)
    country = legal_entity.country

    return nil if country.blank?

    {
      name: country.name,
      code: country.alpha2,
    }
  end

  def ps_names(natural_person)
    [
      {
        type: 'individual',
        fullName: natural_person.name,
      },
    ]
  end

  def ps_nationalities(natural_person)
    country = natural_person.country

    return nil if country.blank?

    [
      {
        name: country.name,
        code: country.alpha2,
      },
    ]
  end

  def ps_addresses(natural_person)
    return nil if natural_person.address.blank?

    [
      {
        address: natural_person.address,
        country: try_parse_country_name_to_code(natural_person.country_of_residence),
      }.compact,
    ]
  end

  def unknown_ps_person_type(unknown_person)
    case unknown_person.unknown_reason_code
    when 'super-secure-person-with-significant-control'
      'anonymousPerson'
    else
      'unknownPerson'
    end
  end

  def ocs_subject(relationship)
    {
      describedByEntityStatement: statement_id(relationship.target),
    }
  end

  def ocs_interested_party(relationship)
    case relationship.source
    when UnknownPersonsEntity
      if ocs_unspecified_reason(relationship.source).present?
        {
          unspecified: {
            reason: ocs_unspecified_reason(relationship.source),
            description: relationship.source.name,
          },
        }
      else
        {
          describedByPersonStatement: statement_id(relationship.source),
        }
      end
    when Entity
      {
        describedByEntityStatement: relationship.source.legal_entity? ? statement_id(relationship.source) : nil,
        describedByPersonStatement: relationship.source.natural_person? ? statement_id(relationship.source) : nil,
      }.compact
    end
  end

  def ocs_interests(relationship)
    relationship.interests.map do |i|
      entry = case i
      when Hash
        if i['exclusive_min'] || i['exclusive_max']
          Rollbar.error('Exporting interests with exclusivity set will overwrite it to false')
        end
        {
          type: i['type'],
          share: if i['share_min'] == i['share_max']
                   {
                     exact: i['share_min'],
                     minimum: i['share_min'],
                     maximum: i['share_max'],
                   }
                 else
                   {
                     minimum: i['share_min'],
                     maximum: i['share_max'],
                     exclusiveMinimum: false,
                     exclusiveMaximum: false,
                   }
                 end,
        }
      when String
        parse_interest_string(i)
      else
        raise "Unexpected value for entry in Relationship#interests - class: #{i.class.name}, value: #{i.inspect}"
      end

      entry[:startDate] = relationship.started_date.try(:to_s)
      entry[:endDate] = relationship.ended_date.try(:to_s)

      entry.compact
    end
  end

  def ocs_source(relationship)
    return ocs_source_from_raw_data(relationship) if relationship.raw_data_provenances.any?

    return nil if relationship.provenance.blank?

    provenance = relationship.provenance

    return nil unless SOURCE_TYPES_MAP.key?(provenance.source_name)

    {
      type: SOURCE_TYPES_MAP[provenance.source_name],
      description: SOURCE_NAMES_MAP.fetch(provenance.source_name, provenance.source_name),
      url: provenance.source_url.presence,
      retrievedAt: provenance.retrieved_at.iso8601,
    }.compact
  end

  def ocs_source_from_raw_data(relationship)
    return nil if relationship.raw_data_provenances.empty?

    provenances = relationship.raw_data_provenances
    imports = provenances.map(&:import).uniq
    if imports.map(&:data_source).uniq.length > 1
      raise "[#{self.class.name}] Relationship: #{relationship.id} comes from multiple data sources, can't produce a single Source for it"
    end

    most_recent_import = imports.max_by(&:created_at)
    data_source = most_recent_import.data_source

    {
      type: data_source.types,
      description: SOURCE_NAMES_MAP.fetch(data_source.name, data_source.name),
      url: data_source.url,
      retrievedAt: most_recent_import.created_at.iso8601,
    }.compact
  end

  def try_parse_country_name_to_code(name)
    return nil if name.blank?

    return ISO3166::Country[name].try(:alpha2) if name.length == 2

    country = ISO3166::Country.find_country_by_name(name)

    return country.alpha2 if country

    country = ISO3166::Country.find_country_by_alpha3(name)

    return country.alpha2 if country
  end
  memoize :try_parse_country_name_to_code

  def parse_interest_string(interest)
    case interest
    when 'ownership-of-shares-25-to-50-percent',
         'ownership-of-shares-25-to-50-percent-as-trust',
         'ownership-of-shares-25-to-50-percent-as-firm'
      {
        type: 'shareholding',
        details: interest,
        share: {
          minimum: 25,
          maximum: 50,
          exclusiveMinimum: true,
          exclusiveMaximum: false,
        },
      }
    when 'ownership-of-shares-50-to-75-percent',
         'ownership-of-shares-50-to-75-percent-as-trust',
         'ownership-of-shares-50-to-75-percent-as-firm'
      {
        type: 'shareholding',
        details: interest,
        share: {
          minimum: 50,
          maximum: 75,
          exclusiveMinimum: true,
          exclusiveMaximum: true,
        },
      }
    when 'ownership-of-shares-75-to-100-percent',
         'ownership-of-shares-75-to-100-percent-as-trust',
         'ownership-of-shares-75-to-100-percent-as-firm'
      {
        type: 'shareholding',
        details: interest,
        share: {
          minimum: 75,
          maximum: 100,
          exclusiveMinimum: false,
          exclusiveMaximum: false,
        },
      }
    when 'voting-rights-25-to-50-percent',
         'voting-rights-25-to-50-percent-as-trust',
         'voting-rights-25-to-50-percent-as-firm',
         'voting-rights-25-to-50-percent-limited-liability-partnership',
         'voting-rights-25-to-50-percent-as-trust-limited-liability-partnership',
         'voting-rights-25-to-50-percent-as-firm-limited-liability-partnership'
      {
        type: 'voting-rights',
        details: interest,
        share: {
          minimum: 25,
          maximum: 50,
          exclusiveMinimum: true,
          exclusiveMaximum: false,
        },
      }
    when 'voting-rights-50-to-75-percent',
         'voting-rights-50-to-75-percent-as-trust',
         'voting-rights-50-to-75-percent-as-firm',
         'voting-rights-50-to-75-percent-limited-liability-partnership',
         'voting-rights-50-to-75-percent-as-trust-limited-liability-partnership',
         'voting-rights-50-to-75-percent-as-firm-limited-liability-partnership'
      {
        type: 'voting-rights',
        details: interest,
        share: {
          minimum: 50,
          maximum: 75,
          exclusiveMinimum: true,
          exclusiveMaximum: true,
        },
      }
    when 'voting-rights-75-to-100-percent',
         'voting-rights-75-to-100-percent-as-trust',
         'voting-rights-75-to-100-percent-as-firm',
         'voting-rights-75-to-100-percent-limited-liability-partnership',
         'voting-rights-75-to-100-percent-as-trust-limited-liability-partnership',
         'voting-rights-75-to-100-percent-as-firm-limited-liability-partnership'
      {
        type: 'voting-rights',
        details: interest,
        share: {
          minimum: 75,
          maximum: 100,
          exclusiveMinimum: false,
          exclusiveMaximum: false,
        },
      }
    when 'right-to-appoint-and-remove-directors',
         'right-to-appoint-and-remove-directors-as-trust',
         'right-to-appoint-and-remove-directors-as-firm',
         'right-to-appoint-and-remove-members-limited-liability-partnership',
         'right-to-appoint-and-remove-members-as-trust-limited-liability-partnership',
         'right-to-appoint-and-remove-members-as-firm-limited-liability-partnership'
      {
        type: 'appointment-of-board',
        details: interest,
      }
    when 'right-to-share-surplus-assets-25-to-50-percent-limited-liability-partnership',
         'right-to-share-surplus-assets-50-to-75-percent-limited-liability-partnership',
         'right-to-share-surplus-assets-75-to-100-percent-limited-liability-partnership',
         'right-to-share-surplus-assets-25-to-50-percent-as-trust-limited-liability-partnership',
         'right-to-share-surplus-assets-50-to-75-percent-as-trust-limited-liability-partnership',
         'right-to-share-surplus-assets-75-to-100-percent-as-trust-limited-liability-partnership',
         'right-to-share-surplus-assets-25-to-50-percent-as-firm-limited-liability-partnership',
         'right-to-share-surplus-assets-50-to-75-percent-as-firm-limited-liability-partnership',
         'right-to-share-surplus-assets-75-to-100-percent-as-firm-limited-liability-partnership'
      # See issue: https://github.com/openownership/data-standard/issues/10
      {
        type: 'rights-to-surplus-assets',
        details: interest,
      }
    when 'significant-influence-or-control'
      {
        type: 'influence-or-control',
        details: interest,
      }
    # rubocop:disable Lint/DuplicateBranch
    else
      # Fallback
      {
        type: 'influence-or-control',
        details: interest,
      }
    end
    # rubocop:enable Lint/DuplicateBranch
  end
  memoize :parse_interest_string

  def ocs_unspecified_reason(unknown_person)
    return if generates_statement?(unknown_person)

    case unknown_person.unknown_reason_code
    when 'no-individual-or-entity-with-signficant-control',
         'no-individual-or-entity-with-signficant-control-partnership'
      'no-beneficial-owners'
    when 'disclosure-transparency-rules-chapter-five-applies',
         'psc-exempt-as-trading-on-regulated-market',
         'psc-exempt-as-shares-admitted-on-market'
      'subject-exempt-from-disclosure'
    when 'steps-to-find-psc-not-yet-completed',
         'steps-to-find-psc-not-yet-completed-partnership'
      'unknown'
    # rubocop:disable Lint/DuplicateBranch
    else
      'unknown'
    end
    # rubocop:enable Lint/DuplicateBranch
  end
end
