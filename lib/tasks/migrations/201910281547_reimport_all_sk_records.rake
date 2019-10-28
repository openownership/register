namespace :migrations do
  desc "Reimport ignored SK records"
  task :reimport_all_sk_records => :environment do
    sk_data_source = DataSource.find_by(document_id: 'Slovakia PSP Register')
    sk_import_ids = Import
      .where(data_source: sk_data_source)
      .pluck(:id)
      .map(&:to_s)
    raw_record_ids = RawDataRecord
      .where(:import_ids.in => sk_import_ids)
      .pluck(:id)
      .map(&:to_s)
    new_import = Import.create! data_source: sk_data_source
    raw_record_ids.each_slice(100) do |record_ids|
      RawDataRecordsImportWorker.perform_async(
        record_ids,
        new_import.created_at,
        new_import.id.to_s,
        'SkImporter',
      )
    end
  end
end
