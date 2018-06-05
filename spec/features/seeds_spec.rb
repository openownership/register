require 'rails_helper'

RSpec.feature "seeds" do
  let(:file) do
    Rails.root.join('db', 'seeds.rb')
  end

  let(:ua_import_task) { double }

  before do
    allow(Entity).to receive(:import)

    allow(Rake.application).to receive(:[]).with('ua:import') { ua_import_task }
    allow(ua_import_task).to receive(:invoke).with('db/ua_seed_data.jsonl', anything)
  end

  it "runs without error" do
    expect { load(file) }.not_to raise_error
  end

  it "imports entities to elasticsearch" do
    load(file)
    expect(Entity).to have_received(:import).with(force: true)
  end
end
