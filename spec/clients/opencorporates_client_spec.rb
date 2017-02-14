require 'rails_helper'

RSpec.describe OpencorporatesClient do
  let(:api_token) { 'api_token_xxx' }

  subject { OpencorporatesClient.new(api_token: api_token) }

  describe '#get_jurisdiction_code' do
    before do
      @url = 'https://api.opencorporates.com/v0.4/jurisdictions/match'
    end

    it 'returns the jurisdiction code matching the given text' do
      stub_request(:get, @url).with(query: "q=United+Kingdom&api_token=#{api_token}").to_return(body: %({"results":{"jurisdiction":{"code":"gb"}}}))

      expect(subject.get_jurisdiction_code('United Kingdom')).to eq('gb')
    end

    it 'returns nil if the jurisdiction is not matched' do
      stub_request(:get, @url).with(query: "q=West+Yorkshire&api_token=#{api_token}").to_return(body: %({"results":{"jurisdiction":{}}}))

      expect(subject.get_jurisdiction_code('West Yorkshire')).to be_nil
    end

    context "when a response error occurs" do
      before do
        stub_request(:get, @url).with(query: "q=United+Kingdom&api_token=#{api_token}").to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*United Kingdom/)
        subject.get_jurisdiction_code('United Kingdom')
      end

      it 'returns nil' do
        expect(subject.get_jurisdiction_code('United Kingdom')).to be_nil
      end
    end
  end

  describe '#get_company' do
    before do
      @jurisdiction_code = 'gb'

      @company_number = '01234567'

      @url = "https://api.opencorporates.com/v0.4/companies/#{@jurisdiction_code}/#{@company_number}"

      @stub = stub_request(:get, @url).with(query: "sparse=true&api_token=#{api_token}")
    end

    it 'returns company data for the given jurisdiction_code and company_number' do
      @stub.to_return(body: %({"results":{"company":{"name":"EXAMPLE LIMITED"}}}))

      expect(subject.get_company(@jurisdiction_code, @company_number)).to eq(name: 'EXAMPLE LIMITED')
    end

    it 'returns nil if the company cannot be found' do
      @stub.to_return(status: 404)

      expect(subject.get_company(@jurisdiction_code, @company_number)).to be_nil
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*#{@jurisdiction_code}.*#{@company_number}/)
        subject.get_company(@jurisdiction_code, @company_number)
      end

      it 'returns nil' do
        expect(subject.get_company(@jurisdiction_code, @company_number)).to be_nil
      end
    end
  end

  describe '#search_companies' do
    before do
      @jurisdiction_code = 'mm'

      @company_number = '919 / 1996-1997'

      @url = 'https://api.opencorporates.com/v0.4/companies/search'

      query = {
        q: @company_number,
        jurisdiction_code: @jurisdiction_code,
        fields: 'company_number',
        order: 'score',
        api_token: api_token
      }

      @stub = stub_request(:get, @url).with(query: query)
    end

    it 'returns an array of results for the given jurisdiction_code and query' do
      @stub.to_return(body: %({"results":{"companies":[{"company":{"name":"MYANMAR IMPERIAL JADE LIMITED"}}]}}))

      results = subject.search_companies(@jurisdiction_code, @company_number)

      expect(results).to be_an(Array)
      expect(results.size).to eq(1)
      expect(results.first).to be_a(Hash)
      expect(results.first.fetch(:company).fetch(:name)).to eq('MYANMAR IMPERIAL JADE LIMITED')
    end

    context "when a response error occurs" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*#{@company_number}.*#{@jurisdiction_code}/)
        subject.search_companies(@jurisdiction_code, @company_number)
      end

      it 'returns empty array' do
        expect(subject.search_companies(@jurisdiction_code, @company_number)).to eq([])
      end
    end
  end
end
