class DkClient
  PAGE_SIZE = 500
  SCROLL_DURATION = '10m'.freeze

  def initialize(username, password)
    @client = Elasticsearch::Client.new url: "http://#{username}:#{password}@distribution.virk.dk"
  end

  def all_records
    Enumerator.new do |yielder|
      r = initial_search

      process_hits(r['hits']['hits'], yielder)

      while r['_scroll_id'].present? &&
            (r = scroll(r['_scroll_id'])) &&
            r['hits']['hits'].present?
        process_hits(r['hits']['hits'], yielder)
      end
    end
  end

  private

  def initial_search
    @client.search(
      index: 'cvr-permanent',
      type: 'deltager',
      scroll: SCROLL_DURATION,
      body: {
        query: {
          match: {
            'Vrdeltagerperson.enhedstype': 'PERSON',
          },
        },
        sort: ['_doc'],
        size: PAGE_SIZE,
      },
    )
  end

  def scroll(scroll_id)
    start = Time.now.utc
    results = @client.scroll(
      body: {
        scroll: SCROLL_DURATION,
        scroll_id: scroll_id,
      },
    )
    duration = (Time.now.utc - start) * 1000
    Rails.logger.info "[#{self.class.name}] Scrolled ElasticSearch in #{duration.round}ms"
    results
  end

  def process_hits(hits, yielder)
    Array(hits).each do |hit|
      yielder << hit['_source']['Vrdeltagerperson']
    end
  end
end
