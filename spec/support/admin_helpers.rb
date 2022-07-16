require 'json'

module AdminHelpers
  def admin_basic_auth
    ActionController::HttpAuthentication::Basic.encode_credentials(*ENV.fetch('ADMIN_BASIC_AUTH').split(':'))
  end

  def stub_elasticsearch
    uri = URI.parse ENV[ENV['ELASTICSEARCH_URL_ENV_NAME']]
    stub_request(:any, /#{uri.host}:#{uri.port}/).to_return(
      status: 200,
      body: {
        name: "f1d20c476493",
        cluster_name: "register-elasticsearch",
        cluster_uuid: "6JVad74qQNyWzGCZ2KXCQw",
        version: {
          number: "7.17.5",
          build_flavor: "default",
          build_type: "docker",
          build_hash: "8d61b4f7ddf931f219e3745f295ed2bbc50c8e84",
          build_date: "2022-06-23T21:57:28.736740635Z",
          build_snapshot: false,
          lucene_version: "8.11.1",
          minimum_wire_compatibility_version: "6.8.0",
          minimum_index_compatibility_version: "6.0.0-beta1",
        },
        tagline: "You Know, for Search",
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-elastic-product' => 'Elasticsearch',
      },
    )
  end

  def stub_opencorporates_client_get_company
    allow(opencorporates_client).to receive(:get_company).and_return(nil)
  end

  def stub_opencorporates_client_search_companies
    allow(opencorporates_client).to receive(:search_companies).and_return([])
  end

  private

  def opencorporates_client
    @opencorporates_client ||= instance_double("OpencorporatesClient").tap do |instance|
      allow(OpencorporatesClient).to receive(:new).and_return(instance)
    end
  end
end
