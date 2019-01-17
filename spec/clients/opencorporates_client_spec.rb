require 'rails_helper'

RSpec.describe OpencorporatesClient do
  let(:api_token) { 'api_token_xxx' }

  let :mock_req_headers do
    {
      'Accept' => 'application/json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Connection' => 'keep-alive',
      'Keep-Alive' => '30',
      'User-Agent' => 'Faraday v0.15.3',
    }
  end

  let :mock_res_headers do
    {
      'Content-Type' => 'application/json',
    }
  end

  let :client do
    OpencorporatesClient.new(
      api_token: api_token,
      open_timeout: 1.0,
      read_timeout: 1.0,
      raise_timeouts: false,
    )
  end

  shared_examples_for "response errors" do |log_text, empty_return_value|
    context "when a response error is returned" do
      before do
        @stub.to_return(status: 500)
      end

      it 'logs response errors' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/500.*#{log_text}/)
        subject
      end

      it 'returns an empty value' do
        expect(subject).to eq(empty_return_value)
      end
    end

    context "when a Faraday::ConnectionFailed error is raised" do
      before do
        @stub.to_raise(Faraday::ConnectionFailed)
      end

      it 'logs response errors' do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Faraday::ConnectionFailed.*#{log_text}/)
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
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(/Faraday::ConnectionFailed.*#{log_text}/)
        subject
      end

      it 'returns an empty value' do
        expect(subject).to eq(empty_return_value)
      end
    end

    context "when a Faraday::Timeout error is raised" do
      before do
        @stub.to_raise(Faraday::TimeoutError)
      end

      context "when raise_timeouts is false" do
        it 'logs response errors' do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:info).with(/Faraday::Timeout.*#{log_text}/)
          subject
        end

        it 'returns an empty value' do
          expect(subject).to eq(empty_return_value)
        end
      end

      context "when raise_timeouts is true" do
        let :client do
          OpencorporatesClient.new(
            api_token: api_token,
            open_timeout: 1.0,
            read_timeout: 1.0,
            raise_timeouts: true,
          )
        end

        it 'logs response errors and raises a TimeoutError' do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:info).with(/Faraday::Timeout.*#{log_text}/)
          expect { subject }.to raise_error(OpencorporatesClient::TimeoutError)
        end
      end
    end
  end

  describe '#get_jurisdiction_code' do
    before do
      url = "https://api.opencorporates.com/#{OpencorporatesClient::API_VERSION}/jurisdictions/match"
      @stub = stub_request(:get, url).with(query: "q=United+Kingdom&api_token=#{api_token}", headers: mock_req_headers)
    end

    subject { client.get_jurisdiction_code('United Kingdom') }

    include_examples "response errors", "United Kingdom", nil

    context "when jurisdiction is matched" do
      before do
        @stub.to_return(body: %({"results":{"jurisdiction":{"code":"gb"}}}), headers: mock_res_headers)
      end

      it 'returns the jurisdiction code matching the given text' do
        expect(subject).to eq('gb')
      end
    end

    context "when jurisdiction is not matched" do
      before do
        @stub.to_return(body: %({"results":{"jurisdiction":{}}}), headers: mock_res_headers)
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

      @stub = stub_request(:get, URI.join(@url, @number)).with(query: "sparse=true&api_token=#{api_token}", headers: mock_req_headers)
    end

    subject { client.get_company('gb', @number) }

    include_examples "response errors", "gb.*01234567", nil

    context "when the company with given jurisdiction_code and company_number is found" do
      before do
        @stub.to_return(body: @body, headers: mock_res_headers)
      end

      it 'returns company data' do
        expect(subject).to eq(name: 'EXAMPLE LIMITED')
      end

      context 'when company number contains square brackets' do
        before do
          @number = '123456[S]'
          stub_request(:get, @url + @number).with(query: "sparse=true&api_token=#{api_token}", headers: mock_req_headers).to_return(body: @body, headers: mock_res_headers)
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
        stub_request(:get, URI.join(@url, @number)).with(query: "api_token=#{api_token}", headers: mock_req_headers).to_return(body: @body, headers: mock_res_headers)
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

      @stub = stub_request(:get, url).with(query: query, headers: mock_req_headers)
    end

    subject { client.search_companies('gb', '01234567') }

    include_examples "response errors", "01234567.*gb", []

    context "when given jurisdiction_code and query returns results" do
      before do
        @stub.to_return(body: %({"results":{"companies":[{"company":{"name":"EXAMPLE LIMITED"}}]}}), headers: mock_res_headers)
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

      @stub = stub_request(:get, url).with(query: query, headers: mock_req_headers)
    end

    subject { client.search_companies_by_name('Example Ltd') }

    include_examples "response errors", "Example Ltd", []

    context "when given name and query returns results" do
      before do
        @stub.to_return(body: %({"results":{"companies":[{"company":{"name":"EXAMPLE LTD"}}]}}), headers: mock_res_headers)
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
