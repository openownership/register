module CountryHelper
  def country_flag(country)
    return unknown_country_flag unless country

    basename = "#{country.alpha2.upcase}.svg"

    return unknown_country_flag unless asset_present?(basename)

    image_tag(basename, size: '32x16', alt: country.name, class: 'flag')
  end

  def country_flag_path(country)
    return path_to_image("flag-unknown.svg") unless country

    basename = "#{country.alpha2.upcase}.svg"
    return path_to_image("flag-unknown.svg") unless asset_present?(basename)

    path_to_image(basename)
  end

  private

  def unknown_country_flag
    glossary_tooltip(
      image_tag("flag-unknown.svg", size: '32x16', alt: "unknown", class: 'flag'),
      :unknown_jurisdiction,
      :top,
    )
  end
end
