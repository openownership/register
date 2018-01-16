require 'rails_helper'

RSpec.describe OpencorporatesClient do
  let(:api_token) { 'api_token_xxx' }

  let(:client) { OpencorporatesClient.new(api_token: api_token) }

  shared_examples_for "response errors" do |log_text, empty_return_value|
    context "when a response error is returned" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/500.*#{log_text}/)
        subject
      end

      it 'returns an empty value' do
        expect(subject).to eq(empty_return_value)
      end
    end

    context "when a response exception is raised" do
      before do
        @stub.to_raise(Net::HTTP::Persistent::Error)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/Net::HTTP::Persistent::Error.*#{log_text}/)
        subject
      end

      it 'returns an empty value' do
        expect(subject).to eq(empty_return_value)
      end
    end

    context "when an open timeout is raised" do
      before do
        allow_any_instance_of(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      end

      it 'logs response errors' do
        expect(Rails.logger).to receive(:info).with(/Net::OpenTimeout.*#{log_text}/)
        subject
      end

      it 'returns an empty value' do
        expect(subject).to eq(empty_return_value)
      end
    end
  end

  describe '#get_jurisdiction_code' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/jurisdictions/match"
      @stub = stub_request(:get, url).with(query: "q=United+Kingdom&api_token=#{api_token}")
    end

    subject { client.get_jurisdiction_code('United Kingdom') }

    include_examples "response errors", "United Kingdom", nil

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
  end

  describe '#get_company' do
    before do
      @number = '01234567'
      @url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/gb/"

      @body = %({"results":{"company":{"name":"EXAMPLE LIMITED"}}})

      @stub = stub_request(:get, URI.join(@url, @number)).with(query: "sparse=true&api_token=#{api_token}")
    end

    subject { client.get_company('gb', @number) }

    include_examples "response errors", "gb.*01234567", nil

    context "when the company with given jurisdiction_code and company_number is found" do
      before do
        @stub.to_return(body: @body)
      end

      it 'returns company data' do
        expect(subject).to eq(name: 'EXAMPLE LIMITED')
      end

      context 'when company number contains square brackets' do
        before do
          @number = '123456[S]'
          stub_request(:get, @url + @number).with(query: "sparse=true&api_token=#{api_token}").to_return(body: @body)
        end

        it 'returns company data' do
          expect(subject).to eq(name: 'EXAMPLE LIMITED')
        end
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
        stub_request(:get, URI.join(@url, @number)).with(query: "api_token=#{api_token}").to_return(body: @body)
      end

      subject { client.get_company('gb', '01234567', sparse: false) }

      it 'calls the endpoint without the sparse parameter' do
        subject
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
        api_token: api_token,
      }

      @stub = stub_request(:get, url).with(query: query)
    end

    subject { client.search_companies('gb', '01234567') }

    include_examples "response errors", "01234567.*gb", []

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
  end

  describe '#search_companies_by_name' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/companies/search"

      query = {
        q: 'Example Ltd',
        fields: 'company_name',
        order: 'score',
        api_token: api_token,
      }

      @stub = stub_request(:get, url).with(query: query)
    end

    subject { client.search_companies_by_name('Example Ltd') }

    include_examples "response errors", "Example Ltd", []

    context "when given name and query returns results" do
      before do
        @stub.to_return(body: %({"results":{"companies":[{"company":{"name":"EXAMPLE LTD"}}]}}))
      end

      it 'returns an array of results' do
        expect(subject).to be_an(Array)
        expect(subject.size).to eq(1)
        expect(subject.first).to be_a(Hash)
        expect(subject.first.fetch(:company).fetch(:name)).to eq('EXAMPLE LTD')
      end
    end
  end
end
