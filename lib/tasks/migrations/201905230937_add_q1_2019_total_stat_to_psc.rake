namespace :migrations do
  desc "Add Q1 2019 TOTAL stat for the PSC data source"
  task :add_q1_2019_total_to_psc => :environment do
    psc = DataSource.find('uk-psc-register')
    # Move the older TOTAL stats to REGISTER_TOTAL
    psc.statistics
      .where(type: DataSourceStatistic::Types::TOTAL)
      .update_all(type: DataSourceStatistic::Types::REGISTER_TOTAL)

    psc.statistics.create!(
      type: DataSourceStatistic::Types::TOTAL,
      value: 4_202_044,
    )
  end
end
