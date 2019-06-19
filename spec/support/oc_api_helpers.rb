def stub_oc_company_api_for(company)
  oc_url = oc_company_api_url(company.jurisdiction_code, company.company_number)
  oc_url_regex = /#{Regexp.quote(oc_url)}/
  stub_request(:get, oc_url_regex).to_return(
    body: '{"results":{"company":{"name":"EXAMPLE LIMITED","previous_names":[{"company_name":"FOO LIMITED"}],"industry_codes":[],"officers":[]}}}',
    headers: { 'Content-Type' => 'application/json' },
  )
end

def stub_oc_company_api_with_fixture(jurisdiction_code, company_number)
  fixture = "oc_api_response_#{jurisdiction_code.downcase}_#{company_number}.json"
  oc_url = oc_company_api_url(jurisdiction_code, company_number)
  oc_url_regex = /#{Regexp.quote(oc_url)}/
  stub_request(:get, oc_url_regex).to_return(
    body: file_fixture(fixture).read,
    headers: { 'Content-Type' => 'application/json' },
  )
end

def oc_company_api_url(jurisdiction_code, company_number)
  "https://api.opencorporates.com/" \
    "#{OpencorporatesClient::API_VERSION}/companies/" \
    "#{jurisdiction_code}/#{company_number}"
end
