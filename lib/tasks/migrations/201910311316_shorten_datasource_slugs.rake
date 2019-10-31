namespace :migrations do
  desc "Shorten and regularise slugs for data sources"
  task :shorten_data_source_slugs => :environment do
    dk = DataSource.find('denmark-central-business-register-centrale-virksomhedsregister-cvr')
    dk.slugs = ['dk-cvr-register']
    dk.save!

    sk = DataSource.find('slovakia-public-sector-partners-register-register-partnerov-verejneho-sektora')
    sk.slugs = ['sk-rpvs-register']
    sk.save!

    ua = DataSource.find('ukraine-consolidated-state-registry-edinyy-derzhavnyj-reestr-edr')
    ua.slugs = ['ua-edr-register']
    ua.save!
  end
end
