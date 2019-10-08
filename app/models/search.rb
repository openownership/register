class Search
  EXCLUDED_TERMS_REGEX = /\b(llp|llc|plc|inc|ltd|limited)\b/i.freeze

  def self.query(search_params)
    query = normalise_query(search_params[:q])

    {
      bool: {
        should: [
          {
            match_phrase: {
              name: {
                query: query,
                slop: 50,
              },
            },
          },
          {
            match_phrase: {
              name_transliterated: {
                query: query,
                slop: 50,
              },
            },
          },
          {
            match: {
              company_number: {
                query: query,
              },
            },
          },
        ],
        minimum_should_match: 1,
        filter: filters(search_params),
      },
    }
  end

  def self.fallback_query(search_params)
    query = normalise_query(search_params[:q])

    {
      bool: {
        should: [
          {
            match: {
              name: {
                query: query,
              },
            },
          },
          {
            match: {
              name_transliterated: {
                query: query,
              },
            },
          },
        ],
        minimum_should_match: 1,
        filter: filters(search_params),
      },
    }
  end

  def self.aggregations
    {
      type: {
        terms: {
          field: :type,
        },
      },
      country: {
        terms: {
          field: :country_code,
        },
      },
    }
  end

  def self.filters(search_params)
    array = []
    array << term_query(:type, search_params[:type])
    array << term_query(:country_code, search_params[:country])
    array.compact
  end

  def self.term_query(key, value)
    return unless value

    {
      term: {
        key => value,
      },
    }
  end

  def self.normalise_query(query)
    return '' if query.blank?

    query.gsub(EXCLUDED_TERMS_REGEX, '').strip
  end
end
