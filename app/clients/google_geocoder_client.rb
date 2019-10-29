class GoogleGeocoderClient
  def initialize
    Geokit::Geocoders::GoogleGeocoder.api_key = ENV['GOOGLE_GEOCODE_API_KEY']
  end

  def jurisdiction(address_string)
    result = Geokit::Geocoders::GoogleGeocoder.geocode(address_string)
    return nil unless result.success?

    result.country_code.downcase
  rescue StandardError => e
    Rollbar.error(e)
    nil
  end
end
