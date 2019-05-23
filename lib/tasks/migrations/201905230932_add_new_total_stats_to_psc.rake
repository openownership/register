namespace :migrations do
  desc "Add REGISTER_TOTAL and TOTAL stats to PSC data source"
  task :add_new_total_stats_to_psc => :environment do
    psc = DataSource.find('uk-psc-register')
    new_stats = [
      DataSourceStatistic::Types::TOTAL,
      DataSourceStatistic::Types::REGISTER_TOTAL,
      DataSourceStatistic::Types::PSC_NO_OWNER,
      DataSourceStatistic::Types::PSC_UNKNOWN_OWNER,
      DataSourceStatistic::Types::PSC_OFFSHORE_RLE,
      DataSourceStatistic::Types::PSC_NON_LEGIT_RLE,
      DataSourceStatistic::Types::PSC_SECRECY_RLE,
      DataSourceStatistic::Types::DISSOLVED,
    ]
    psc.update_attribute(:current_statistic_types, new_stats)
  end
end
