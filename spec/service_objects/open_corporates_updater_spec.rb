require 'rails_helper'

RSpec.describe OpenCorporatesUpdater do
  it 'queues up an update for every entity resolved over a month ago' do
    create(:legal_entity, last_resolved_at: 1.month.ago)
    create(:legal_entity, last_resolved_at: 1.month.ago + 1.day)
    create(:legal_entity, last_resolved_at: Time.zone.now)
    expect do
      OpenCorporatesUpdater.new.call
    end.to change(OpenCorporatesUpdateWorker.jobs, :size).by(1)
  end

  it 'includes entities which have never been resolved' do
    create(:legal_entity, last_resolved_at: nil)
    expect do
      OpenCorporatesUpdater.new.call
    end.to change(OpenCorporatesUpdateWorker.jobs, :size).by(1)
  end
end
