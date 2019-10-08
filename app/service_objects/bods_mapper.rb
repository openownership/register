require 'xxhash'

class BodsMapper
  extend Memoist

  def self.instance
    @instance ||= new
  end

  SOURCE_TYPES_MAP = {
    'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])' => %w[officialRegister],
    'EITI pilot data' => %w[thirdParty primaryResearch],
    'OpenOwnership Register' => %w[thirdParty selfDeclaration],
    'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)' => %w[officialRegister],
    'UK PSC Register' => %w[officialRegister],
    'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])' => %w[officialRegister],
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
    return true unless entity.respond_to? :unknown_reason

    REASONS_FOR_UNKNOWN_PERSON_STATEMENT.include?(entity.unknown_reason)
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
      missingInfoReason: unknown_person.name,
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
    entity.identifiers.map do |i|
      case i['document_id']
      when 'GB PSC Snapshot'
        if entity.legal_entity?
          if i.key?('company_number') && !i.key?('link')
            {
              scheme: 'GB-COH',
              id: i['company_number'],
            }
          end
        elsif entity.natural_person?
          nil # No unique identifier for people from this data source
        end
      when 'Denmark CVR'
        if entity.legal_entity?
          {
            scheme: 'DK-CVR',
            id: i['company_number'],
          }
        elsif entity.natural_person?
          {
            scheme: 'MISC-Denmark CVR',
            id: i['beneficial_owner_id'],
          }
        end
      when 'Slovakia PSP Register'
        if entity.legal_entity?
          {
            scheme: 'SK-ORSR',
            id: i['company_number'],
          }
        elsif entity.natural_person?
          {
            scheme: 'MISC-Slovakia PSP Register',
            id: i['beneficial_owner_id'],
          }
        end
      when 'Ukraine EDR'
        if entity.legal_entity?
          {
            scheme: 'UA-EDR',
            id: i['company_number'],
          }
        elsif entity.natural_person?
          nil # No unique identifier for people from this data source
        end
      end
    end.compact
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
    case unknown_person.unknown_reason
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
        {
          type: i['type'],
          share: if i['share_min'] == i['share_max']
                   {
                     exact: i['share_min'],
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
      description: provenance.source_name,
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
      description: data_source.name,
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
    else
      # Fallback
      {
        type: 'influence-or-control',
        details: interest,
      }
    end
  end
  memoize :parse_interest_string

  def ocs_unspecified_reason(unknown_person)
    return if generates_statement?(unknown_person)

    case unknown_person.unknown_reason
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
    else
      'unknown'
    end
  end
end
