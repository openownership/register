require 'rails_helper'

RSpec.describe SkClient do
  let(:url) { 'https://rpvs.gov.sk/OpenData/Partneri' }
  let(:query) { '$expand=PartneriVerejnehoSektora($expand=*),KonecniUzivateliaVyhod($expand=*)' }

  describe '#all_records' do
    subject { SkClient.new.all_records }

    it 'returns an enumerator' do
      expect(subject).to be_an(Enumerator)
    end

    it 'fetches all the data from the api and yields each record' do
      initial_request = stub_request(:get, url).with(query: query).to_return(body: file_fixture('sk_bo_data.json').read)
      second_request = stub_request(:get, url).with(query: "#{query}&$skip=20").to_return(body: file_fixture('sk_bo_data_end.json').read)

      subject.each do |record|
        expect(record).to be_a(Hash)
      end
      expect(initial_request).to have_been_requested
      expect(second_request).to have_been_requested
    end

    context 'when a response error occurs' do
      before do
        stub_request(:get, url).with(query: query).to_return(status: 500)
      end

      it 'logs the error' do
        expect(Rollbar).to receive(:error).with("500 received when importing sk data")
        subject.to_a
      end
    end
  end

  describe '#company_record' do
    let(:url) { 'https://rpvs.gov.sk/OpenData/Partneri(1)' }
    subject { SkClient.new.company_record(1) }

    it 'returns a Hash with Partneri and Konecni arrays' do
      stub_request(:get, url).with(query: query).to_return(body: file_fixture('sk_company_datum.json').read)
      result = subject
      expect(result).to be_a(Hash)
      expect(result['PartneriVerejnehoSektora']).to be_a(Array)
      expect(result['KonecniUzivateliaVyhod']).to be_a(Array)
    end

    context 'when a response error occurs' do
      before do
        stub_request(:get, url).with(query: query).to_return(status: 500)
      end

      it 'logs the error' do
        expect(Rollbar).to receive(:error).with("500 received when importing sk data")
        subject
      end
    end
  end
end
