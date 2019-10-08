namespace :migrations do
  desc "Move RawDataRecord.data Hashes into JSON in .raw_data"
  task :move_raw_data_into_strings => :environment do
    RawDataRecord.each do |record|
      next if record.raw_data.present?

      raw_data = record.data.to_json
      etag = record.data.dig('data', 'etag').presence || RawDataRecord.etag(raw_data)
      record.update_attributes!(raw_data: raw_data, etag: etag, data: nil)
    end
  end
end
