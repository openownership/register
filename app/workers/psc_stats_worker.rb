class PscStatsWorker
  include Sidekiq::Worker

  PSC_DOCUMENT_ID = 'GB PSC Snapshot'.freeze

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

  def perform(entity_id, data_source_id, stat_ids)
    entity = Entity.find(entity_id)
    data_source = DataSource.find(data_source_id)
    stats = stat_ids.map { |t, id| [t, data_source.statistics.draft.find(id)] }.to_h

    if entity.dissolution_date.present?
      increment(stats, STAT_TYPES::DISSOLVED)
      # We don't count these towards the total
      return
    end

    increment(stats, STAT_TYPES::REGISTER_TOTAL)
    # How many have no declared owner at all?
    if no_declared_owner?(entity)
      increment(stats, STAT_TYPES::PSC_NO_OWNER)
      # None of the more detailed questions about RLEs are relevant
      return
    end
    # How many companies make some kind of statement about not having a
    # beneficial owner?
    increment(stats, STAT_TYPES::PSC_UNKNOWN_OWNER) if current_suspicious_statements(entity).any?
    # How many have a company as an owner, where that company doesn't meet the
    # requirements for being a Relevant Legal Owner (RLE) or looks suspicious?
    non_uk_rles = current_non_uk_rles(entity)
    # Not in the UK
    increment(stats, STAT_TYPES::PSC_OFFSHORE_RLE) if non_uk_rles.any?
    # Not in any allowed RLE jurisdiction
    increment(stats, STAT_TYPES::PSC_NON_LEGIT_RLE) if non_legit_rles(non_uk_rles).any?
    # In the list of 'secrecy' jurisdiction
    increment(stats, STAT_TYPES::PSC_SECRECY_RLE) if secrecy_rles(non_uk_rles).any?
  end

  private

  def increment(stats, type)
    stats[type].inc(value: 1)
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

    current_statements = current_statements(entity)
    return false if current_statements.any?

    true
  end

  def current_statements(entity)
    Statement
      .where(
        '_id.document_id' => PSC_DOCUMENT_ID,
        :ended_date => nil,
        :entity => entity,
      )
  end

  def current_suspicious_statements(entity)
    current_statements(entity).where(
      type: { '$in' => SUSPICIOUS_STATEMENT_TYPES },
    )
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
