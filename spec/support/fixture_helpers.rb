def psc_json_fixture(filepath)
  record = create(:raw_data_record, raw_data: file_fixture(filepath).read)
  [record]
end

def sk_json_fixture(filepath)
  data = JSON.parse file_fixture(filepath).read
  if data['value'].present?
    data['value'].map { |r| create(:raw_data_record, raw_data: r.to_json) }
  else
    create(:raw_data_record, raw_data: data.to_json)
  end
end

def dk_json_fixture(filepath)
  create(:raw_data_record, raw_data: file_fixture(filepath).read)
end
