def psc_json_fixture(filepath)
  records = JSON.parse file_fixture(filepath).read
  [records]
end
