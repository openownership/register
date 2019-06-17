def psc_json_fixture(filepath)
  data = JSON.parse file_fixture(filepath).read
  record = create(:raw_data_record, data: data)
  [record]
end
