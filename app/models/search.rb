class Search
  def self.query(search_params)
    {
      bool: {
        should: [
          {
            match_phrase: {
              name: {
                query: search_params[:q],
                slop: 50,
              },
            },
          },
          {
            match_phrase: {
              name_transliterated: {
                query: search_params[:q],
                slop: 50,
              },
            },
          },
          {
            match: {
              company_number: {
                query: search_params[:q],
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
end
