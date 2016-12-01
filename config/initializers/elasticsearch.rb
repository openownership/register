if ENV.key?('SEARCHBOX_SSL_URL')
  Elasticsearch::Model.client = Elasticsearch::Client.new(url: ENV['SEARCHBOX_SSL_URL'])
end
