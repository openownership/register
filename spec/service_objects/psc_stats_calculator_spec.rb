require 'rails_helper'

RSpec.describe PscStatsCalculator do
  include PscStatsHelpers
  let!(:data_source) { create(:psc_data_source) }

  STAT_TYPES = DataSourceStatistic::Types

  describe 'calculating the total number of companies' do
    let!(:company) { uk_psc_company }

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(type: STAT_TYPES::TOTAL)
    end

    it 'creates a DataSourceStatistic for the total' do
      # Given a company that meets the criteria
      # When we ask for the stats
      # Then it creates one DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And it counts the company for that stat
      expect(stats.first.value).to eq 1
    end

    it 'ignores companies from other sources, even UK ones' do
      # Given a company that meets the criteria
      # And a company that's from the UK, but not from the PSC data
      create(:legal_entity, jurisdiction_code: 'gb')
      # And a company that's from elsewhere entirely
      create(:legal_entity, jurisdiction_code: 'sk')
      # When we ask for the stats
      # Then it only counts the one company
      expect(stats.first.value).to eq 1
    end

    it 'ignores dissolved companies' do
      # Given a company that meets the criteria
      # When we dissolve that company
      company.update_attributes!(dissolution_date: '2019-03-25')
      # Then it stops counting that company
      expect(stats.first.value).to eq 0
    end
  end

  describe 'calculating the number of dissolved companies' do
    let!(:company) { uk_psc_company }
    let!(:dissolved_company) { uk_psc_company }

    before do
      dissolved_company.update_attributes!(dissolution_date: '2019-03-25')
    end

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(type: STAT_TYPES::DISSOLVED)
    end

    it 'creates a DataSourceStatistic for the total number of dissolved companies' do
      # Given a company that meets the criteria
      # When we ask for the stats
      # Then it creates one DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And it counts the company for that stat
      expect(stats.first.value).to eq 1
    end

    it 'ignores companies from other sources, even UK ones' do
      # Given a company that meets the criteria
      # And a company that's from the UK, but not from the PSC data
      create(:legal_entity, jurisdiction_code: 'gb', dissolution_date: '2019-03-25')
      # And a company that's from elsewhere entirely
      create(:legal_entity, jurisdiction_code: 'sk', dissolution_date: '2019-03-25')
      # When we ask for the stats
      # Then it only counts the one company
      expect(stats.first.value).to eq 1
    end
  end

  describe 'calculating the number of unknown owners via Statements' do
    let!(:statement) { uk_psc_statement(uk_psc_company) }

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(type: STAT_TYPES::PSC_UNKNOWN_OWNER)
    end

    it 'creates a DataSourceStatistic for the number of unknown owners' do
      # Given a company with a Statement about its ownership being unknown
      # When we ask for its stats
      # Then it creates one DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And it counts one company for that stat
      expect(stats.first.value).to eq 1
    end

    it 'only counts current statements' do
      # Given a company with a Statement about its ownership being unknown
      # And another company with a statement, but one that's ended
      statement = uk_psc_statement(uk_psc_company)
      statement.update_attributes!(ended_date: '2019-03-25')
      # When we ask for the stats
      # Then it doesn't count the company with an ended statement
      expect(stats.first.value).to eq 1
    end

    it 'only counts PSC statements' do
      # Given a company with a Statement about its ownership being unknown
      # And another statement about a company from another source
      create(:statement)
      # When we ask for the stats
      # Then it doesn't count the other statement
      expect(stats.first.value).to eq 1
    end

    it 'ignores super secure persons and exemptions' do
      # Given a company with a Statement about its ownership being unknown
      # And a company with a super-secure statement
      super_secure_statement = uk_psc_statement(uk_psc_company)
      super_secure_statement.update_attributes!(type: 'super-secure-persons-with-significant-control')
      # And a company with an chapter 5 exemption
      exempt_statement1 = uk_psc_statement(uk_psc_company)
      exempt_statement1.update_attributes!(type: 'disclosure-transparency-rules-chapter-five-applies')
      # And a company with a regulated market exemption
      exempt_statement2 = uk_psc_statement(uk_psc_company)
      exempt_statement2.update_attributes!(type: 'psc-exempt-as-trading-on-regulated-market')
      # And a company with a shares market exemption
      exempt_statement3 = uk_psc_statement(uk_psc_company)
      exempt_statement3.update_attributes!(type: 'psc-exempt-as-shares-admitted-on-market')
      # When we ask for the stats
      # Then it doesn't count any of those other statements
      expect(stats.first.value).to eq 1
    end

    it "doesn't double count entities with multiple statements" do
      # Given a company with a Statement about its ownership being unknown
      # And a second statement about that company
      uk_psc_statement(statement.entity)
      # When we ask for the stats
      # Then it still only counts one company
      expect(stats.first.value).to eq 1
    end

    it "doesn't count statements for dissolved companies" do
      # Given a company with a Statement about its ownership being unknown
      # And a dissolved company with a statement
      dissolved_company = uk_psc_company
      dissolved_company.update_attributes!(dissolution_date: '2019-03-25')
      uk_psc_statement(dissolved_company)
      # When we ask for the stats
      # Then it still only counts one company
      expect(stats.first.value).to eq 1
    end
  end

  describe 'calculating the number of missing owners' do
    let!(:missing_owner_company) { uk_psc_company }

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(type: STAT_TYPES::PSC_NO_OWNER)
    end

    it 'creates a DataSourceStatistic for the number of missing owners' do
      # Given a company without an ownership
      # When we ask for the stats
      # Then it creates one DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And it counts one company for that stat
      expect(stats.first.value).to eq 1
    end

    it 'ignores companies with Statements' do
      # Given a company without an ownership
      # When we make a statement about that company
      uk_psc_statement(missing_owner_company)
      # Then it stops counting that company
      expect(stats.first.value).to eq 0
    end

    it 'ignores companies with owners' do
      # Given a company without an ownership
      # When there's an owner for the company
      person = create(:natural_person, identifiers: [psc_identifier])
      create(:relationship, id: psc_identifier, source: person, target: missing_owner_company)
      # Then it doesn't count that company
      expect(stats.first.value).to eq 0
    end

    it 'ignores non-UK companies, even from PSC Data' do
      # Given a company without an ownership
      # And a foreign company that is from PSC
      uk_psc_company.update_attributes!(jurisdiction_code: 'us')
      # And a foreign company that's not from PSC
      create(:legal_entity, jurisdiction_code: 'gg')
      # When we ask for the stats
      # Then it doesn't count either foreign company
      expect(stats.first.value).to eq 1
    end

    it 'only counts current companies' do
      # Given a company without an ownership
      # When the company is dissolved
      missing_owner_company.update_attributes!(dissolution_date: '2019-03-25')
      # It no longer counts that company
      expect(stats.first.value).to eq 0
    end

    it 'only counts ownerships found through PSC data' do
      # Given a company without an ownership
      # When we add an ownership from somewhere else
      # (with a non-UK company so that it isn't counted as having a missing
      # owner itself)
      second_company = create(:legal_entity, jurisdiction_code: 'dk')
      create(:relationship, source: second_company, target: missing_owner_company)
      # Then it still counts the first company as having a 'missing owner'
      expect(stats.first.value).to eq 1
    end
  end

  describe 'calculating the number of non-UK RLEs' do
    let!(:company_with_rle) { uk_psc_company_with_rle_in('us') }

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(type: STAT_TYPES::PSC_OFFSHORE_RLE)
    end

    it 'creates a DataSourceStatistic for the number of non-UK RLEs' do
      # Given a company with an RLE for an owner
      # When we calculate the stats
      # Then it creates a DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And counts one company for the stat
      expect(stats.first.value).to eq 1
    end

    it 'ignores UK RLEs' do
      # Given a company with an RLE for an owner
      # And a company with a UK RLE
      uk_psc_company_with_rle_in('gb')
      # When we ask for the stats
      # Then it doesn't count the company with UK RLE
      expect(stats.first.value).to eq 1
    end

    it 'ignores RLEs with no jurisdiction_code or an invalid code' do
      # Given a company with an RLE for an owner
      # And a company with an RLE with no jurisdiction
      uk_psc_company_with_rle_in('')
      # And a company in a non-existent jurisdiction
      uk_psc_company_with_rle_in('xx')
      # When we ask for the stats
      # Then it doesn't count either company
      expect(stats.first.value).to eq 1
    end

    it 'only counts current relationships' do
      # Given a company with an RLE for an owner
      # When the relationship ends
      relationship = company_with_rle.relationships_as_target.first
      relationship.update_attributes!(ended_date: '2019-03-25')
      # Then it stops counting the company
      expect(stats.first.value).to eq 0
    end

    it 'only counts relationships that have come through PSC data' do
      # Given a company with an RLE for an owner
      # And a company with an RLE we got from a different source
      # (both companies are from the PSC data, but the relationship isn't)
      rle = create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: 'gb')
      company = create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: 'gb')
      create(:relationship, source: rle, target: company)
      # When we ask for the stats
      # Then it doesn't count the company with an RLE from a different source
      expect(stats.first.value).to eq 1
    end

    it "doesn't double count companies with multiple RLEs" do
      # Given a company with an RLE for an owner
      # When we add a second non-UK RLE
      second_rle = create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: 'gg')
      create(:relationship, source: second_rle, target: company_with_rle)
      # Then it still counts a single company
      expect(stats.first.value).to eq 1
    end

    it "counts companies that have both UK and non-UK RLEs" do
      # Given a company with an RLE for an owner
      # When we add a second UK RLE
      second_rle = create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: 'gb')
      create(:relationship, source: second_rle, target: company_with_rle)
      # Then it still counts the company
      expect(stats.first.value).to eq 1
    end
  end

  describe 'calculating the number of non-legit RLEs' do
    # Mexico
    let!(:company_with_rle) { uk_psc_company_with_rle_in('mx') }

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(
        type: STAT_TYPES::PSC_NON_LEGIT_RLE,
      )
    end

    it 'creates a DataSourceStatistic for the number of non-legit RLEs' do
      # Given a company with an RLE in a non-legit jurisdiction
      # When we ask for the stats
      # Then it creates a DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And counts one company for the stat
      expect(stats.first.value).to eq 1
    end

    it 'ignores UK, US, Swiss, Japanese, Israeli and EU RLEs' do
      # Given a company with an RLE in a non-legit jurisdiction
      # And companies with RLEs in legit jurisdictions
      %w[gb us ch jp il sk].map do |jurisdiction|
        uk_psc_company_with_rle_in(jurisdiction)
      end
      # When we ask for the stats
      # Then it only counts the original company
      expect(stats.first.value).to eq 1
    end
  end

  describe 'calculating the number of secrecy jurisdiction RLEs' do
    # Cayman Islands
    let!(:company_with_rle) { uk_psc_company_with_rle_in('ky') }

    subject(:stats) do
      PscStatsCalculator.new.call
      data_source.reload
      data_source.statistics.where(type: STAT_TYPES::PSC_SECRECY_RLE)
    end

    it 'creates a DataSourceStatistic for the number of secrecy RLEs' do
      # Given a company with an RLE in a secrecy jurisdiction
      # When we ask for the stats
      # Then it creates a DataSourceStatistic of the right type
      expect(stats.count).to eq 1
      # And counts one company
      expect(stats.first.value).to eq 1
    end

    it 'ignores non-secrecy RLEs' do
      # Given a company with an RLE in a secrecy jurisdiction
      # And a company with an RLE in the UK
      uk_psc_company_with_rle_in('gb')
      # And a company with an RLE in the US (a legit RLE jurisdiction)
      uk_psc_company_with_rle_in('us')
      # And a company with an RLE in guernesy (a non-legit RLE jurisdiction)
      uk_psc_company_with_rle_in('mx')
      # When we ask for the stats
      # Then it ignores all those other companies
      expect(stats.first.value).to eq 1
    end
  end

  it 'can count the same RLE for multiple stats' do
    # Given an company with an RLE in a secrecy jurisdiction
    # (which is also offshore and not a legit jurisdiction)
    uk_psc_company_with_rle_in('ky')

    # When we ask for the stats for all three types of RLE
    PscStatsCalculator.new.call
    data_source.reload
    stats = data_source.statistics.where(
      type: {
        "$in" => [
          STAT_TYPES::PSC_OFFSHORE_RLE,
          STAT_TYPES::PSC_NON_LEGIT_RLE,
          STAT_TYPES::PSC_SECRECY_RLE,
        ],
      },
    )
    # Then it counts the RLE once for each stat
    expect(stats.count).to eq 3
    stats.each do |stat|
      expect(stat.value).to eq 1
    end
  end
end
