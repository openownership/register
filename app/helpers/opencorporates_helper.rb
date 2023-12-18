# frozen_string_literal: true

module OpencorporatesHelper
  def alternate_names(company_hash)
    company_hash[:alternative_names].pluck(:company_name).join(', ')
  end

  def previous_names(company_hash)
    company_hash[:previous_names].pluck(:company_name).join(', ')
  end

  def industry_codes(company_hash)
    company_hash[:industry_codes].map do |hash|
      "#{hash[:industry_code][:code]} #{hash[:industry_code][:description]}"
    end.join(', ')
  end

  def officers(company_hash)
    company_hash[:officers].pluck(:officer).reject { |hash| hash[:inactive] }
  end

  def officer_attributes_snippet(officer_hash)
    parts = []
    parts << officer_hash[:position].capitalize if officer_hash[:position]
    parts << "(#{officer_hash[:start_date]} – #{officer_hash[:end_date]})" if officer_hash[:start_date]
    parts.compact.join(' ')
  end
end
