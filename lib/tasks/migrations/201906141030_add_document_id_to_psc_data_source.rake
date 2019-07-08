namespace :migrations do
  desc "Add document_id to PSC data source"
  task :add_document_id_to_psc_data_source => :environment do
    psc = DataSource.find('uk-psc-register')
    psc.update_attribute(:document_id, 'GB PSC Snapshot')
  end
end
