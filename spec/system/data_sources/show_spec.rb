require 'rails_helper'

RSpec.describe 'Data Source pages' do
  include PscStatsHelpers

  context 'basic data sources with no stats or content' do
    let(:data_source) { create(:data_source, name: 'EITI', url: nil) }

    it "shows a basic page and doesn't include anything else" do
      visit data_source_url(data_source)
      expect(page).to have_text(data_source.name)

      expect(page).not_to have_css('.meta', text: I18n.t('data_sources.show.links_title'))
      expect(page).not_to have_css('.meta', text: I18n.t('data_sources.show.news_title'))
      expect(page).not_to have_text(I18n.t('data_sources.show.overview_title'))
      expect(page).not_to have_text(I18n.t('data_sources.show.data_availability_title'))
      expect(page).not_to have_text(I18n.t('data_sources.show.data_statistics_title'))
    end
  end

  context 'PSC Data Source' do
    let!(:psc_data_source) do
      create(
        :psc_data_source,
        overview: 'test [markdown](http://example.com/overview)',
        data_availability: 'test [markdown](http://example.com/availability)',
        timeline_url: 'http://example.com/twitter',
        current_statistic_types: [
          DataSourceStatistic::Types::TOTAL,
          DataSourceStatistic::Types::REGISTER_TOTAL,
          DataSourceStatistic::Types::PSC_NO_OWNER,
          DataSourceStatistic::Types::PSC_UNKNOWN_OWNER,
          DataSourceStatistic::Types::PSC_OFFSHORE_RLE,
          DataSourceStatistic::Types::PSC_NON_LEGIT_RLE,
          DataSourceStatistic::Types::PSC_SECRECY_RLE,
          DataSourceStatistic::Types::DISSOLVED,
        ],
      )
    end

    let(:expected_stats) do
      {
        DataSourceStatistic::Types::TOTAL => 15,
        # The 12 non-dissolved below + two we added in with normal ownerships
        DataSourceStatistic::Types::REGISTER_TOTAL => 14,
        DataSourceStatistic::Types::PSC_NO_OWNER => 4,
        DataSourceStatistic::Types::PSC_UNKNOWN_OWNER => 5,
        DataSourceStatistic::Types::PSC_OFFSHORE_RLE => 3,
        DataSourceStatistic::Types::PSC_NON_LEGIT_RLE => 2,
        DataSourceStatistic::Types::PSC_SECRECY_RLE => 1,
        DataSourceStatistic::Types::DISSOLVED => 1,
      }
    end

    # Note that we don't expect a dissolved stat, dissolved companues are not
    # included in the total so they don't get percentages calculated
    let(:expected_stats_percentages) do
      {
        DataSourceStatistic::Types::TOTAL => 100.0,
        DataSourceStatistic::Types::REGISTER_TOTAL => 93.3,
        DataSourceStatistic::Types::PSC_NO_OWNER => 26.7,
        DataSourceStatistic::Types::PSC_UNKNOWN_OWNER => 33.3,
        DataSourceStatistic::Types::PSC_OFFSHORE_RLE => 20.0,
        DataSourceStatistic::Types::PSC_NON_LEGIT_RLE => 13.3,
        DataSourceStatistic::Types::PSC_SECRECY_RLE => 6.7,
      }
    end

    before do
      # How many companies are there in the real world, outside of those who are
      # reporting PSCs? One more than the total we have in the register.
      create(
        :data_source_statistic,
        type: DataSourceStatistic::Types::TOTAL,
        value: 15,
        data_source: psc_data_source,
      )

      # Things we should count

      # 5 Statements
      5.times { uk_psc_statement(uk_psc_company) }

      # 4 Companies missing BO declarations
      4.times { uk_psc_company }

      # 3 Companies with non-uk RLEs

      # 1 Legit
      uk_psc_company_with_rle_in('us')

      # 1 Non-legit (but not secrecy)
      uk_psc_company_with_rle_in('mx')

      # 1 Secrecy jurisdiction (also counts towards non-legit)
      uk_psc_company_with_rle_in('ky')

      # 1 ended company (should only count towards dissolved companies)
      uk_psc_company.update_attributes!(dissolution_date: '2019-03-29')

      # Things we shouldn't count

      # UK Companies from other sources
      create(:legal_entity)

      # Foreign companies from other sources
      create(:legal_entity, jurisdiction_code: 'us')

      # Ended statements (counts towards total but not statement count)
      company_with_ended_statement = uk_psc_company
      uk_psc_statement(company_with_ended_statement).update_attributes!(ended_date: '2019-03-29')
      # Add an ownership to keep it out of the stats
      create(:relationship, target: company_with_ended_statement, id: psc_identifier)

      # Ended RLE relationships (counts towards total but not rle count)
      company_with_ended_rle = uk_psc_company_with_rle_in('ky')
      company_with_ended_rle.relationships_as_target.first.update_attributes!(ended_date: '2019-03-29')
      # Add an ownership to keep it out of the stats
      create(:relationship, target: company_with_ended_rle, id: psc_identifier)

      # UK PSC sourced companies without a jurisdiction_code
      uk_psc_company.update_attributes!(jurisdiction_code: '')

      PscStatsCalculator.new.call
    end

    it 'Shows a full page with content and statistics' do
      visit data_source_url(psc_data_source)
      expect(page).to have_text(psc_data_source.name)
      expect(page).to have_text(I18n.t('data_sources.show.links_title'))
      expect(page).to have_link(
        I18n.t('data_sources.show.source_url_link'),
        href: psc_data_source.url,
      )
      expect(page).to have_text(I18n.t('data_sources.show.overview_title'))
      expect(page).to have_text(I18n.t('data_sources.show.data_availability_title'))
      # Test that markdown was parsed correctly in the content
      expect(page).to have_link(href: 'http://example.com/overview')
      expect(page).to have_link(href: 'http://example.com/availability')
      # Twitter timeline won't load without JS, which is for the best in specs
      expect(page).to have_text(I18n.t('data_sources.show.news_title'))
      expect(page).to have_link(I18n.t('data_sources.show.news_fallback_text'))

      # Statistics
      expect(page).to have_text(I18n.t('data_sources.show.statistics_title'))
      expect(page).to have_text(I18n.t('data_source_statistics.total.title'))
      expect(page.html).to include(I18n.t('data_source_statistics.total.footnote_html'))
      expect(page).to have_text(I18n.t('data_source_statistics.register_total.title'))
      expect(page.html).to include(I18n.t('data_source_statistics.register_total.footnote_html'))
      expect(page).to have_text(I18n.t('data_source_statistics.psc_no_owner.title'))
      expect(page.html).to include(I18n.t('data_source_statistics.psc_no_owner.footnote_html'))
      expect(page).to have_text(I18n.t('data_source_statistics.psc_unknown_owner.title'))
      expect(page.html).to include(I18n.t('data_source_statistics.psc_unknown_owner.footnote_html'))
      expect(page).to have_text(I18n.t('data_source_statistics.psc_offshore_rle.title'))
      expect(page).to have_text(I18n.t('data_source_statistics.psc_non_legit_rle.title'))
      expect(page.html).to include(I18n.t('data_source_statistics.psc_non_legit_rle.footnote_html'))
      expect(page).to have_text(I18n.t('data_source_statistics.psc_secrecy_rle.title'))
      expect(page.html).to include(I18n.t('data_source_statistics.psc_secrecy_rle.footnote_html'))
      expect(page).to have_text(I18n.t('data_source_statistics.dissolved.title'))

      expected_stats.each do |type, value|
        within(".statistic-#{type.dasherize}") do
          expect(page).to have_css('.statistic-count', text: value)
        end
      end

      expected_stats_percentages.each do |type, value|
        within(".statistic-#{type.dasherize}") do
          expect(page).to have_css('.statistic-percentage', text: "#{value}%")
        end
      end
    end
  end
end
