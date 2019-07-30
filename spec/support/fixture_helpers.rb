def psc_json_fixture(filepath)
  data = JSON.parse file_fixture(filepath).read
  record = create(:raw_data_record, data: data)
  [record]
end

def sk_json_fixture(filepath)
  data = JSON.parse file_fixture(filepath).read
  if data['value'].present?
    data['value'].map { |r| create(:raw_data_record, data: r) }
  else
    create(:raw_data_record, data: data)
  end
end
