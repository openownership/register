module Submissions
  module EntitiesHelper
    COUNTRIES_TO_SUBDIVIDE = [
      ISO3166::Country.new('US'),
      ISO3166::Country.new('CA'),
    ].freeze

    def countries_for_select
      sorted_countries.map { |c| [c.names.first, c.alpha2.downcase] }
    end

    def jurisdictions_for_select(default_value = nil)
      safe_join(sorted_countries.map { |c| country_for_select(c, default_value) })
    end

    def form_options_for_entity(entity)
      if entity.persisted?
        {
          model: entity,
          url: submission_entity_path(entity.submission, entity),
          method: :put,
          scope: :entity,
          local: true,
        }
      else
        {
          model: entity,
          url: submission_entities_path(entity.submission),
          method: :post,
          scope: :entity,
          local: true,
        }
      end
    end

    private

    def sorted_countries
      ISO3166::Country.all.sort_by { |c| c.names.first.parameterize }
    end

    def country_for_select(country, default_value)
      value = country.alpha2.downcase
      label = "#{country.names.first} (#{value})"

      options_for_select([[label, value]], default_value).tap do |options|
        options << country_with_subdivisions_for_select(country, default_value) if COUNTRIES_TO_SUBDIVIDE.include?(country)
      end
    end

    def country_with_subdivisions_for_select(country, default_value)
      options = country.subdivisions.map do |code, subdivision|
        value = "#{country.alpha2}_#{code}".downcase
        label = "#{subdivision.name} (#{value})"

        [label, value]
      end

      grouped_options_for_select([[country.names.first, options]], default_value)
    end
  end
end
