require 'rails_helper'

RSpec.feature "seeds" do
  let(:file) do
    File.join(Rails.root, 'db', 'seeds.rb')
  end

  before do
    allow(Entity).to receive(:import)
  end

  it "runs without error" do
    expect { load(file) }.not_to raise_error
  end

  it "imports entities to elasticsearch" do
    load(file)
    expect(Entity).to have_received(:import).with(force: true)
  end
end
