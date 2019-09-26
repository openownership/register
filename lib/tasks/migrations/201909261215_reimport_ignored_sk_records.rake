namespace :migrations do
  desc "Reimport ignored SK records"
  task :reimport_ignored_sk_records => :environment do
    sk_data_source = DataSource.find_by(document_id: 'Slovakia PSP Register')
    sk_imports = Import.where(data_source: sk_data_source)
    latest_import = sk_imports.max_by(&:created_at)
    all_record_ids = Set.new(
      RawDataRecord
        .where(import_ids: latest_import)
        .distinct(:id)
        .map(&:to_s),
    )
    imported_record_ids = Set.new(
      RawDataProvenance
        .where(:import_id.in => sk_imports.map(&:id))
        .distinct(:raw_data_record_ids)
        .flatten
        .compact
        .map(&:to_s),
    )
    unimported_records = all_record_ids - imported_record_ids

    unimported_records.each_slice(100) do |record_ids|
      RawDataRecordsImportWorker.perform_async(record_ids, latest_import.created_at, latest_import.id.to_s, 'SkImporter')
    end
  end
end
