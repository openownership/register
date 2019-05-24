class PscStatsCalculator
  PSC_SOURCE_SLUG = 'uk-psc-register'.freeze
  PSC_DOCUMENT_ID = 'GB PSC Snapshot'.freeze
  STAT_TYPES = [
    DataSourceStatistic::Types::REGISTER_TOTAL,
    DataSourceStatistic::Types::PSC_UNKNOWN_OWNER,
    DataSourceStatistic::Types::PSC_NO_OWNER,
    DataSourceStatistic::Types::PSC_OFFSHORE_RLE,
    DataSourceStatistic::Types::PSC_NON_LEGIT_RLE,
    DataSourceStatistic::Types::PSC_SECRECY_RLE,
    DataSourceStatistic::Types::DISSOLVED,
  ].freeze

  def call
    psc_data_source = DataSource.find(PSC_SOURCE_SLUG)
    stat_ids = create_draft_stats(psc_data_source)
    psc_uk_legal_entities.no_timeout.each do |entity|
      PscStatsWorker.perform_async(entity.id, psc_data_source.id, stat_ids)
    end
  end

  private

  def create_draft_stats(data_source)
    stat_ids = {}
    STAT_TYPES.map do |type|
      stat = data_source.statistics.create!(type: type, value: 0, published: false)
      stat_ids[type] = stat.id
    end
    stat_ids
  end

  # All the companies from the PSC register which are based in the UK.
  # We're only concerned with UK companies, which isn't the same as companies
  # that are in the PSC data, because we get told about offshore companies via
  # the ownerships there too.
  def psc_uk_legal_entities
    Entity
      .legal_entities
      .where(
        'identifiers.document_id' => PSC_DOCUMENT_ID,
        :jurisdiction_code => 'gb',
      )
  end
end
