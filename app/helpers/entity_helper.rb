module EntityHelper
  def entity_jurisdiction(entity)
    return unless (country = entity.country)
    return country.name unless (country_subdivision = entity.country_subdivision)
    "#{country_subdivision.name} (#{country.name})"
  end

  def entity_country_flag(entity)
    return unless (country = entity.country)

    basename = "#{country.alpha2.upcase}.svg"

    return unless asset_present?(basename)

    image_tag(basename, size: '32x16', alt: country.name, class: 'flag')
  end
end
