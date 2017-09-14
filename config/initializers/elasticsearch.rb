Elasticsearch::Model.client = Elasticsearch::Client.new(url: ENV[ENV['ELASTICSEARCH_URL_ENV_NAME']])
