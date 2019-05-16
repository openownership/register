class BodsCompanyNumberExtractor
  def initialize(scheme)
    @scheme = scheme
  end

  def extract(identifiers)
    company_number_identifier = identifiers.find { |i| i['scheme'] == @scheme }
    return if company_number_identifier.blank?
    company_number_identifier["id"]
  end
end
