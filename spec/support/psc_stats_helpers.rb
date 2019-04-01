module PscStatsHelpers
  def psc_identifier
    { document_id: 'GB PSC Snapshot', link: "/test/#{SecureRandom.uuid}" }
  end

  def uk_psc_company
    create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: 'gb')
  end

  def uk_psc_statement(company)
    create(:statement, id: psc_identifier, entity: company)
  end

  def uk_psc_company_with_rle_in(jurisdiction)
    rle = create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: jurisdiction)
    company = create(:legal_entity, identifiers: [psc_identifier], jurisdiction_code: 'gb')
    create(:relationship, id: psc_identifier, source: rle, target: company)
    company
  end
end
