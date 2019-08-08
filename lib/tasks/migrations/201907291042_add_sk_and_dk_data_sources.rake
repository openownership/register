namespace :migrations do
  desc "Add SK and DK data sources"
  task :add_sk_and_dk_data_sources => :environment do
    DataSource.create!(
      name: 'Slovakia Public Sector Partners Register (Register partnerov verejného sektora)',
      url: 'https://rpvs.gov.sk/',
      document_id: 'Slovakia PSP Register',
      current_statistic_types: [],
    )
    DataSource.create!(
      name: 'Denmark Central Business Register (Centrale Virksomhedsregister [CVR])',
      url: 'https://cvr.dk',
      document_id: 'Denmark CVR',
      current_statistic_types: [],
    )
  end
end
