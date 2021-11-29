namespace :migrations do
  desc "Update PSC data source overview content"
  task :update_psc_data_source_overview => :environment do
    psc = DataSource.find('uk-psc-register')
    new_overview = File.read(Rails.root.join('db/psc_register_overview.md'))
    psc.update_attribute(:overview, new_overview)
  end
end
