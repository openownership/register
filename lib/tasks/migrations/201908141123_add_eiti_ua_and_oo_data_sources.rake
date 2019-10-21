namespace :migrations do
  desc "Add EITI and UA data sources"
  task :add_eiti_ua_and_oo_data_sources => :environment do
    # For submitted data
    unless DataSource.where(name: 'OpenOwnership Register').exists?
      DataSource.create!(
        name: 'OpenOwnership Register',
        url: 'https://register.openownership.org',
        document_id: nil,
        current_statistic_types: [],
        types: %w[thirdParty selfDeclaration],
      )
    end

    # EITI Pilot data
    # We create one data_source for each spreadsheet tab since they all have
    # different document ids
    eiti_file = Rails.root.join('db', 'data', 'eiti-data.txt')
    File.readlines(eiti_file).each do |line|
      data = JSON.parse(line)
      country_name = data['document_id'].gsub('EITI Structured Data - ', '')
      name = "EITI pilot data - #{country_name}"
      next if DataSource.where(name: name).exists?

      DataSource.create!(
        name: name,
        url: data['url'],
        document_id: data['document_id'],
        current_statistic_types: [],
        types: %w[thirdParty primaryResearch],
      )
    end

    ua_name = 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])'
    unless DataSource.where(name: ua_name).exists?
      DataSource.create!(
        name: ua_name,
        url: 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10',
        document_id: 'Ukraine EDR',
        current_statistic_types: [],
        types: %w[officialRegister],
      )
    end
  end
end
