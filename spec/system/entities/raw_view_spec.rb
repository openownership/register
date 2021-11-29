require 'rails_helper'

RSpec.describe 'Entity raw data page' do
  include EntityHelpers

  let!(:entity) { create(:legal_entity) }
  let(:data_source1) { create(:data_source, name: 'Data Source 1') }
  let(:data_source2) { create(:data_source, name: 'Data Source 2') }
  let(:oldest) { 10.days.ago }
  let(:newest) { 1.day.ago }
  let(:import1) do
    import = create(:import, data_source: data_source1)
    import.timeless.update_attribute(:created_at, oldest)
    import
  end
  let(:import2) do
    import = create(:import, data_source: data_source2)
    import.timeless.update_attribute(:created_at, newest)
    import
  end

  let!(:import1_provenances) do
    create_list(:raw_data_provenance, 5, entity_or_relationship: entity, import: import1)
  end
  let!(:import2_provenances) do
    create_list(:raw_data_provenance, 5, entity_or_relationship: entity, import: import2)
  end
  let(:provenances_in_order) do
    import1_provenances.sort_by(&:updated_at) + import2_provenances
  end
  let(:raw_records) { provenances_in_order.map(&:raw_data_records).flatten }

  before do
    # Create some realistic timestamps on the raw data
    import1_provenances.map(&:raw_data_records).flatten.each do |record|
      record.timeless.update_attribute(:created_at, oldest)
      record.timeless.update_attribute(:updated_at, oldest)
    end

    import2_provenances.map(&:raw_data_records).flatten.each do |record|
      record.timeless.update_attribute(:created_at, newest)
      record.timeless.update_attribute(:updated_at, newest)
    end

    # Make it so some records have been seen in more than one data source
    # and more than one import
    import1_provenances.first.raw_data_records.each do |record|
      record.imports << import2
      record.timeless.update_attribute(:updated_at, newest)
    end
  end

  it 'shows the entity name and nationality/jurisdiction' do
    visit raw_entity_path(entity)
    expect(page).to have_text(entity.name)
  end

  it 'paginates the raw records, showing most recently updated first' do
    visit raw_entity_path(entity)

    expect(page).to have_text 'Displaying raw records 1 - 10 of 20 in total'

    expect(page).to have_text provenances_in_order[-5].raw_data_records.last.etag
    expect(page).not_to have_text provenances_in_order[-6].raw_data_records.first.etag

    within '.pagination' do
      within '.current' do
        expect(page).to have_text('1')
      end
      expect(page).to have_link '2'
      expect(page).to have_link 'Next ›'
      expect(page).to have_link 'Last »'
      click_link '2'
    end

    expect(page).to have_text 'Displaying raw records 11 - 20 of 20 in total'

    expect(page).not_to have_text provenances_in_order[-5].raw_data_records.last.etag
    expect(page).to have_text provenances_in_order[-6].raw_data_records.first.etag

    expect(page).to have_text provenances_in_order[-10].raw_data_records.last.etag

    within '.pagination' do
      within '.current' do
        expect(page).to have_text('2')
      end
      expect(page).to have_link '1'
      expect(page).to have_link '« First'
      expect(page).to have_link '‹ Prev'
    end
  end

  it 'shows the data sources for all the raw records' do
    visit raw_entity_path(entity)
    expect(page).to have_text('Data source(s) Data Source 1 and Data Source 2', normalize_ws: true)
  end

  it 'shows the newest/oldest dates for all the raw records' do
    visit raw_entity_path(entity)
    expect(page).to have_text("Oldest #{oldest}", normalize_ws: true)
    expect(page).to have_text("Newest #{newest}", normalize_ws: true)
  end

  it 'shows the formatted data for each raw record' do
    visit raw_entity_path(entity)

    raw_records.last(10).each do |record|
      within "#raw_data_record_#{record.etag}" do
        expected = JSON.pretty_generate(JSON.parse(record.raw_data)).gsub(/\s+/, ' ')
        expect(page).to have_text(expected, normalize_ws: true)
      end
    end
  end

  it 'shows the data sources for each raw record' do
    visit raw_entity_path(entity)
    raw_records.last(8).each do |record|
      within "#raw_data_record_#{record.etag}" do
        expect(page).to have_text("First seen #{record.created_at}", normalize_ws: true)
        expect(page).to have_text("Last seen #{record.updated_at}", normalize_ws: true)
      end
    end
  end

  it 'shows the first and last seen dates for each raw record' do
    visit raw_entity_path(entity)
    raw_records.last(10).each do |record|
      within "#raw_data_record_#{record.etag}" do
        expect(page).to have_text("First seen #{record.created_at}", normalize_ws: true)
        expect(page).to have_text("Last seen #{record.updated_at}", normalize_ws: true)
      end
    end
  end

  it "shows whether each record was seen in the most recent import for it's data source" do
    # We need a third import here, so that some records can be missing from the
    # most recent import for a data source
    import3 = create(:import, data_source: data_source2)
    create(
      :raw_data_provenance,
      raw_data_records: [provenances_in_order.last.raw_data_records.last],
      import: import3,
    )
    provenances_in_order.last.raw_data_records.last.imports << import3
    # Important to mimic what would happen in a real import, because << doesn't
    # trigger the timestamping, but our bulk import does
    provenances_in_order.last.raw_data_records.last.touch

    visit raw_entity_path(entity)

    within "#raw_data_record_#{raw_records.last.etag}" do
      expect(page).to have_text("Seen in most recent import? Yes", normalize_ws: true)
    end

    raw_records.last(10).first(9).each do |record|
      within "#raw_data_record_#{record.etag}" do
        expect(page).to have_text("Seen in most recent import? No", normalize_ws: true)
      end
    end
  end
end
