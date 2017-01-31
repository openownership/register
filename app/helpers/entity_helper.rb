module EntityHelper
  def entity_jurisdiction(entity)
    jurisdiction_code = entity.jurisdiction_code

    return if jurisdiction_code.nil?

    country_code, subdivision_code = jurisdiction_code.split('_')

    country = ISO3166::Country.find_country_by_alpha2(country_code)

    return country.name if subdivision_code.nil?

    subdivision = country.subdivisions.fetch(subdivision_code.upcase)

    "#{subdivision.name} (#{country.name})"
  end

  def entity_country_flag(entity)
    jurisdiction_code = entity.jurisdiction_code

    return if jurisdiction_code.nil?

    country_code = jurisdiction_code.split('_').first

    country = ISO3166::Country.find_country_by_alpha2(country_code)

    basename = "#{country_code.upcase}.svg"

    return unless asset_present?(basename)

    image_tag(basename, size: '32x16', alt: country.name, class: 'flag')
  end
end
