require 'rails_helper'

RSpec.describe 'Additional entity info from OpenCorporates' do
  include EntityHelpers
  include_context 'basic entity with stubbed OC api'

  context 'when the OC api has data for an entity' do
    it 'displays an info box with the OC data', js: true do
      visit entity_path(company)
      expected_attribution = I18n.t("entities.show.data_from_opencorporates_html", opencorporates: "OpenCorporates")
      expect(page).to have_text(expected_attribution)
      expect(page).to have_text("FOO LIMITED")
    end
  end

  context "when the OC api doesn't have any data for an entity" do
    before do
      stub_request(:get, oc_url_regex).to_return(status: 404)
    end

    it 'displays a message that no data is available', js: true do
      visit entity_path(company)
      expected_msg = I18n.t("entities.show.no_data_from_opencorporates")
      expect(page).to have_text(expected_msg)
    end
  end

  context "when js is disabled" do
    it 'displays a message that js is required' do
      visit entity_path(company)
      expected_msg = I18n.t("shared.javascript_required")
      expect(page).to have_text(expected_msg)
    end
  end
end
