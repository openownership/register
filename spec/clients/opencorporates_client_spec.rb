require 'rails_helper'

RSpec.describe OpencorporatesClient do
  let(:api_token) { 'api_token_xxx' }

  let(:client) { OpencorporatesClient.new(api_token: api_token) }

  describe '#get_jurisdiction_code' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/jurisdictions/match"
      @stub = stub_request(:get, url).with(query: "q=United+Kingdom&api_token=#{api_token}")
    end

    subject { client.get_jurisdiction_code('United Kingdom') }

    context "when jurisdiction is matched" do
      before do
        @stub.to_return(body: %({"results":{"jurisdiction":{"code":"gb"}}}))
      end

      it 'returns the jurisdiction code matching the given text' do
        expect(subject).to eq('gb')
      end
    end

    context "when jurisdiction is not matched" do
      before do
        @stub.to_return(body: %({"results":{"jurisdiction":{}}}))
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*United Kingdom/)
        subject
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#get_company' do
    before do
      @url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/gb/01234567"

      @body = %({"results":{"company":{"name":"EXAMPLE LIMITED"}}})

      @stub = stub_request(:get, @url).with(query: "sparse=true&api_token=#{api_token}")
    end

    subject { client.get_company('gb', '01234567') }

    context "when the company with given jurisdiction_code and company_number is found" do
      before do
        @stub.to_return(body: @body)
      end

      it 'returns company data' do
        expect(subject).to eq(name: 'EXAMPLE LIMITED')
      end
    end

    context "when the company cannot be found" do
      before do
        @stub.to_return(status: 404)
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when called with sparse: false' do
      before do
        stub_request(:get, @url).with(query: "api_token=#{api_token}").to_return(body: @body)
      end

      subject { client.get_company('gb', '01234567', sparse: false) }

      it 'calls the endpoint without the sparse parameter' do
        subject
      end
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*gb.*01234567/)
        subject
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#search_companies' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/search"

      query = {
        q: '01234567',
        jurisdiction_code: 'gb',
        fields: 'company_number',
        order: 'score',
        api_token: api_token
      }

      @stub = stub_request(:get, url).with(query: query)
    end

    subject { client.search_companies('gb', '01234567') }

    context "when given jurisdiction_code and query returns results" do
      before do
        @stub.to_return(body: %({"results":{"companies":[{"company":{"name":"EXAMPLE LIMITED"}}]}}))
      end

      it 'returns them' do
        expect(subject).to be_an(Array)
        expect(subject.size).to eq(1)
        expect(subject.first).to be_a(Hash)
        expect(subject.first.fetch(:company).fetch(:name)).to eq('EXAMPLE LIMITED')
      end
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*01234567.*gb/)
        subject
      end

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end
  end
end
