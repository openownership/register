require 'rails_helper'

RSpec.describe PscImportTrigger do
  describe '.call' do
    let(:data_source) { create(:psc_data_source) }
    let(:link_one) { 'psc-snapshot-2019-06-13_1of14.zip' }
    let(:link_two) { 'psc-snapshot-2019-06-13_2of14.zip' }
    let(:download_page) do
      html = '<a href="persons-with-significant-control-snapshot-2019-06-13.zip">persons-with-significant-control-snapshot-2019-06-13.zip</a>'
      html += "<a href=\"#{link_one}\">psc-snapshot-2019-06-13_1of14.zip  (63Mb)</a>"
      html += "<a href=\"#{link_two}\">psc-snapshot-2019-06-13_2of14.zip  (63Mb)</a>"
      html
    end

    before do
      stub_request(:get, data_source.url).to_return(body: download_page)
    end

    subject { PscImportTrigger.new.call(data_source, 100) }

    it 'enqueues a PscFileProcessorWorker for every snapshot link' do
      expect do
        subject
      end.to change(PscFileProcessorWorker.jobs, :size).by(2)

      first_link = PscFileProcessorWorker.jobs.first['args'].first
      second_link = PscFileProcessorWorker.jobs.second['args'].first
      expected_links = [
        "http://download.companieshouse.gov.uk/#{link_one}",
        "http://download.companieshouse.gov.uk/#{link_two}",
      ]
      expect([first_link, second_link]).to match_array(expected_links)
    end
  end
end
