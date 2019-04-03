namespace :migrations do
  desc "Add in existing data sources"
  task :add_psc_data_source => :environment do
    DataSource.create!(
      name: 'UK PSC Register',
      url: 'http://download.companieshouse.gov.uk/en_pscdata.html',
      overview: File.read(Rails.root.join('db', 'psc_register_overview.md')),
      data_availability: File.read(Rails.root.join('db', 'psc_register_data_availability.md')),
      timeline_url: 'https://twitter.com/sheislaurence/timelines/1107584066134654976?ref_src=twsrc%5Etfw',
      current_statistic_types: [
        DataSourceStatistic::Types::PSC_NO_OWNER,
        DataSourceStatistic::Types::PSC_UNKNOWN_OWNER,
        DataSourceStatistic::Types::PSC_OFFSHORE_RLE,
        DataSourceStatistic::Types::PSC_NON_LEGIT_RLE,
        DataSourceStatistic::Types::PSC_SECRECY_RLE,
      ],
    )
  end
end
