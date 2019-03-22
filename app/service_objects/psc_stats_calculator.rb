class PscStatsCalculator
  # TODO: Store identifier in the DataSource
  # TODO: Get importers to look in the DataSource for these kinds of details
  # TODO: Give DataSource's a slug so we can pass that around
  # TODO: Add an index on Entity.identifiers.document_id

  PSC_DOCUMENT_ID = 'GB PSC Snapshot'.freeze
  PSC_SOURCE_SLUG = 'uk-psc-register'.freeze
  # What kinds of 'Statement' about not having an owner are cause for suspicion?
  # Basically everything except 'exemptions' and 'super-secure persons' for now
  SUSPICIOUS_STATEMENT_TYPES = %w[
    no-individual-or-entity-with-signficant-control
    psc-exists-but-not-identified
    psc-details-not-confirmed
    steps-to-find-psc-not-yet-completed
    psc-contacted-but-no-response
    psc-has-failed-to-confirm-changed-details
    restrictions-notice-issued-to-psc
    no-individual-or-entity-with-signficant-control-partnership
    psc-exists-but-not-identified-partnership
    psc-details-not-confirmed-partnership
    steps-to-find-psc-not-yet-completed-partnership
    psc-contacted-but-no-response-partnership
    psc-has-failed-to-confirm-changed-details-partnership
    restrictions-notice-issued-to-psc-partnership
  ].freeze

  module Jurisdictions
    UK = 'GB'.freeze
    # EEA (EU + Norway, Iceland, Lichtenstein), UK, US, Japan, Switzerland,
    # Israel
    LEGIT_RLE = %w[
      GB JP US CH IL NO IS LI AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT
      LU MT NL PL PT RO SK SI ES SE
    ].freeze
    # Scoring 60 or above on:
    # https://www.financialsecrecyindex.com/introduction/fsi-2018-results
    # Note that on the website, this includes USA, but in their spreadsheet, USA
    # scores 59.83 (i.e. it gets rounded up) so it's not in here.
    SECRECY = %w[
      CH KY HK SG TW AE GG LB PA JP NL TH VG BH JE BS MT MO CY KE CN RU TR MY IL
      BM SA LR MH PH IM UA LI RO BB MU AI ID CR CL PY KN PR VU UY AW DO TZ SC GT
      WS GI CW VE VI TC BO BZ BN MC MV GH DM AG ME CK GD MK BW AD GM TT NR SM LC
      VC MS
    ].freeze
  end

  # To save some typing
  STAT_TYPES = DataSourceStatistic::Types

  def call
    stats = {
      STAT_TYPES::TOTAL => 0,
      STAT_TYPES::PSC_UNKNOWN_OWNER => 0,
      STAT_TYPES::PSC_NO_OWNER => 0,
      STAT_TYPES::PSC_OFFSHORE_RLE => 0,
      STAT_TYPES::PSC_NON_LEGIT_RLE => 0,
      STAT_TYPES::PSC_SECRECY_RLE => 0,
    }

    # How many companies make some kind of statement about not having a
    # beneficial owner?
    stats[STAT_TYPES::PSC_UNKNOWN_OWNER] = current_owner_statements.size
    current_uk_legal_entities.no_timeout.each do |entity|
      stats[STAT_TYPES::TOTAL] += 1
      # How many have no declared owner at all?
      if no_declared_owner?(entity)
        stats[STAT_TYPES::PSC_NO_OWNER] += 1
        # None of the more detailed questions about RLEs are relevant
        next
      end
      # How many have a company as an owner, where that company doesn't meet the
      # requirements for being a Relevant Legal Owner (RLE) or looks suspicious?
      non_uk_rles = current_non_uk_rles(entity)
      # Not in the UK
      stats[STAT_TYPES::PSC_OFFSHORE_RLE] += 1 if non_uk_rles.any?
      # Not in any allowed RLE jurisdiction
      stats[STAT_TYPES::PSC_NON_LEGIT_RLE] += 1 if non_legit_rles(non_uk_rles).any?
      # In the list of 'secrecy' jurisdiction
      stats[STAT_TYPES::PSC_SECRECY_RLE] += 1 if secrecy_rles(non_uk_rles).any?
    end

    save_stats(stats)
  end

  private

  def save_stats(stats)
    Rails.logger.info "[#{self.class.name}] calculated stats: #{stats.inspect}"
    psc_data_source = DataSource.find(PSC_SOURCE_SLUG)
    stats.map do |type, value|
      psc_data_source.statistics.create!(type: type, value: value)
    end
  end

  def current_owner_statements
    # At the moment Statements only come from the PSC register, but we add a
    # condition on that as well, just in case.
    Statement
      .where(
        '_id.document_id' => PSC_DOCUMENT_ID,
        :type => { '$in' => SUSPICIOUS_STATEMENT_TYPES },
        :ended_date => nil,
      )
      .distinct(:entity_id)
  end

  # All the current companies from the PSC register which are based in the UK.
  # We're only concerned with UK companies, which isn't the same as companies
  # that are in the PSC data, because we get told about offshore companies via
  # the ownerships there too.
  def current_uk_legal_entities
    Entity
      .includes(:relationships_as_source, :_relationships_as_target)
      .where(
        :type => Entity::Types::LEGAL_ENTITY,
        'identifiers.document_id' => PSC_DOCUMENT_ID,
        :jurisdiction_code => Jurisdictions::UK.downcase,
        :dissolution_date => nil,
      )
  end

  # Is the entity missing any kind of declaration about its ownership
  # altogether?
  # This couldn't happen for a company directly declared in the PSC, because by
  # definition there's some kind of ownership declaration for it to exist, but a
  # company might declare an RLE in the UK, and that company might not have made
  # any declaration at all.
  def no_declared_owner?(entity)
    current_psc_ownerships = Relationship
      .where(
        target: entity,
        '_id.document_id' => PSC_DOCUMENT_ID,
        :ended_date => nil,
      )
    return false if current_psc_ownerships.any?

    current_statements = Statement
      .where(
        '_id.document_id' => PSC_DOCUMENT_ID,
        :ended_date => nil,
        :entity => entity,
      )
    return false if current_statements.any?

    true
  end

  # Direct parent companies which are not in the UK, current relationships only
  def current_non_uk_rles(entity)
    Relationship
      .includes(:source)
      .where(
        '_id.document_id' => PSC_DOCUMENT_ID,
        :target => entity,
        :ended_date => nil,
      )
      .uniq(&:source_id)
      .map(&:source)
      .select do |source|
        source.legal_entity? \
          && source.country_code.present? \
          && source.country_code != Jurisdictions::UK
      end
  end

  def non_legit_rles(rles)
    rles.reject do |rle|
      Jurisdictions::LEGIT_RLE.include?(rle.country_code)
    end
  end

  def secrecy_rles(rles)
    rles.select do |rle|
      Jurisdictions::SECRECY.include?(rle.country_code)
    end
  end
end
