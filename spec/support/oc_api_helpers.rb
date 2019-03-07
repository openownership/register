def stub_oc_company_api_for(company)
  oc_url = "https://api.opencorporates.com/" \
    "#{OpencorporatesClient::API_VERSION}/companies/" \
    "#{company.jurisdiction_code}/#{company.company_number}"
  oc_url_regex = /#{Regexp.quote(oc_url)}/
  stub_request(:get, oc_url_regex).to_return(
    body: '{"results":{"company":{"name":"EXAMPLE LIMITED","previous_names":[{"company_name":"FOO LIMITED"}],"industry_codes":[],"officers":[]}}}',
    headers: { 'Content-Type' => 'application/json' },
  )
end
