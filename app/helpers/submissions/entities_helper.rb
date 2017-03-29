module Submissions
  module EntitiesHelper
    COUNTRIES_TO_SUBDIVIDE = [
      ISO3166::Country.new('US'),
      ISO3166::Country.new('CA')
    ].freeze

    def countries_for_select
      sorted_countries.map { |c| [c.names.first, c.alpha2.downcase] }
    end

    def jurisdictions_for_select
      safe_join sorted_countries.map(&method(:country_for_select))
    end

    def form_options_for_entity(entity)
      if entity.persisted?
        {
          url: submission_entity_path(entity.submission, entity),
          method: :put
        }
      else
        {
          url: submission_entities_path(entity.submission),
          method: :post
        }
      end
    end

    private

    def sorted_countries
      ISO3166::Country.all.sort_by { |c| c.names.first.parameterize }
    end

    def country_for_select(country)
      value = country.alpha2.downcase
      label = "#{country.names.first} (#{value})"

      options_for_select([[label, value]]).tap do |options|
        options << country_with_subdivisions_for_select(country) if COUNTRIES_TO_SUBDIVIDE.include?(country)
      end
    end

    def country_with_subdivisions_for_select(country)
      options = country.subdivisions.map do |code, subdivision|
        value = "#{country.alpha2}_#{code}".downcase
        label = "#{subdivision.name} (#{value})"

        [label, value]
      end

      grouped_options_for_select([[country.names.first, options]])
    end
  end
end
