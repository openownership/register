class BodsCompanyNumberExtractor
  attr_accessor :schemes

  def initialize(schemes)
    @schemes = schemes
  end

  def extract(identifiers)
    company_number_identifier = identifiers.find do |i|
      @schemes.include?(i['scheme']) && i.key?('id')
    end
    return if company_number_identifier.blank?

    company_number_identifier['id']
  end
end
