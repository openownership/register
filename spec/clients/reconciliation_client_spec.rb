require 'rails_helper'

RSpec.describe ReconciliationClient do
  subject { ReconciliationClient.new }

  describe '#reconcile' do
    before do
      @jurisdiction_code = 'ca'

      @name = 'Example Company'

      @url = "https://opencorporates.com/reconcile/#{@jurisdiction_code}"

      query = {
        query: @name,
      }

      @stub = stub_request(:get, @url).with(query: query)
    end

    it 'returns company data for the given jurisdiction_code and company name' do
      @stub.to_return(body: %({"result":[{"id":"/companies/ca/1234567","name":"EXAMPLE COMPANY LTD."}]}))

      response = subject.reconcile(@jurisdiction_code, @name)

      expect(response).to be_a(Hash)
      expect(response.fetch(:jurisdiction_code)).to eq('ca')
      expect(response.fetch(:company_number)).to eq('1234567')
      expect(response.fetch(:name)).to eq('EXAMPLE COMPANY LTD.')
    end

    it 'returns nil if there are no results' do
      @stub.to_return(body: %({"result":[]}))

      response = subject.reconcile(@jurisdiction_code, @name)

      expect(response).to be_nil
    end

    it 'returns nil if there is a response exception' do
      @stub.to_raise(Net::HTTP::Persistent::Error)

      response = subject.reconcile(@jurisdiction_code, @name)

      expect(response).to be_nil
    end

    it 'raises an exception for response errors' do
      @stub.to_return(status: 500)

      expect { subject.reconcile(@jurisdiction_code, @name) }.to raise_error(ReconciliationClient::Error)
    end
  end
end
