namespace :migrations do
  desc "Add EITI and UA data sources"
  task :add_types_to_existing_data_sources => :environment do
    existing_data_sources = %w[
      uk-psc-register
      slovakia-public-sector-partners-register-register-partnerov-verejneho-sektora
      denmark-central-business-register-centrale-virksomhedsregister-cvr
    ]
    existing_data_sources.each do |slug|
      data_source = DataSource.find(slug)
      unless data_source.types.include? 'officialRegister'
        data_source.types << 'officialRegister'
      end
      data_source.save!
    end
  end
end
