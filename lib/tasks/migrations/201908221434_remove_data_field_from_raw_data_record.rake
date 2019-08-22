namespace :migrations do
  desc "Remove RawDataRecord.data field"
  task :remove_data_field_from_raw_data_record => :environment do
    RawDataRecord.collection.update_many({}, '$unset' => { 'data' => true })
  end
end
