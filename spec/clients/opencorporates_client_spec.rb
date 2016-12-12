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

    it 'raises an exception for response errors' do
      stub_request(:get, @url).with(query: "q=United+Kingdom&api_token=#{api_token}").to_return(status: 500)

      expect { subject.get_jurisdiction_code('United Kingdom') }.to raise_error(OpencorporatesClient::Error)
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

    it 'raises an exception for other response errors' do
      @stub.to_return(status: 500)

      expect { subject.get_company(@jurisdiction_code, @company_number) }.to raise_error(OpencorporatesClient::Error)
    end
  end
end
