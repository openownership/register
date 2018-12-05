def psc_json_fixture(filepath)
  json = file_fixture(filepath).read
  records = JSON.parse(json, symbolize_names: true, object_class: OpenStruct)
  Array(records)
end
