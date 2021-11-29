require 'rails_helper'

RSpec.describe 'the data download page' do
  let!(:exports) do
    exports = create_list(:bods_export, 6, completed_at: Time.zone.now)
    exports.each_with_index do |export, i|
      export.timeless.update_attribute(:created_at, i.days.ago)
    end
    exports
  end
  let!(:export_in_progress) do
    export = create(:bods_export)
    export.timeless.update_attribute(:created_at, 10.days.ago)
    export
  end

  it 'shows links to the most recent completed imports, and the latest' do
    visit '/'

    click_link 'Download our data'

    exports.take(5).each do |export|
      expected_href = "https://oo-register-production.s3-eu-west-1.amazonaws.com/public/exports/statements.#{export.created_at.iso8601}.jsonl.gz"
      expect(page).to have_link(export.created_at.to_date.to_s, href: expected_href)
    end

    expected_href = "https://oo-register-production.s3-eu-west-1.amazonaws.com/public/exports/statements.#{exports.last.created_at.iso8601}.jsonl.gz"
    expect(page).not_to have_link(exports.last.created_at.to_date.to_s, href: expected_href)

    expected_href = "https://oo-register-production.s3-eu-west-1.amazonaws.com/public/exports/statements.#{export_in_progress.created_at.iso8601}.jsonl.gz"
    expect(page).not_to have_link(export_in_progress.created_at.to_date.to_s, href: expected_href)

    expect(page).to have_link 'Download', href: 'https://oo-register-production.s3-eu-west-1.amazonaws.com/public/exports/statements.latest.jsonl.gz'
  end
end
