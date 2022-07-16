require 'rails_helper'

RSpec.describe DkClient do
  let(:elasticsearch_client) { instance_double('Elasticsearch::Transport::Client') }

  before do
    allow(Elasticsearch::Client).to receive(:new).and_return(elasticsearch_client)
  end

  describe '#all_records' do
    subject { DkClient.new('u', 'p').all_records }

    let :first_results do
      {
        '_scroll_id' => 's123',
        'hits' => {
          'hits' => [
            { '_source' => { 'Vrdeltagerperson' => {} } },
            { '_source' => { 'Vrdeltagerperson' => {} } },
          ],
        },
      }
    end

    let :second_results do
      {
        'hits' => {
          'hits' => [{ '_source' => { 'Vrdeltagerperson' => {} } }],
        },
      }
    end

    before do
      allow(elasticsearch_client).to receive(:search)
        .and_return(first_results)

      allow(elasticsearch_client).to receive(:scroll)
        .with(hash_including(body: hash_including(scroll_id: 's123')))
        .and_return(second_results)
        .once
    end

    it 'returns an enumerator' do
      expect(subject).to be_an(Enumerator)
    end

    it 'fetches data using the scroll API, yields each record, then fetches the next set of results' do
      results = subject.to_a
      expect(results.length).to be 3
      expect(results).to all be_a(Hash)
    end
  end
end
