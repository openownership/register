require 'rails_helper'

RSpec.feature "seeds" do
  let(:file) do
    File.join(Rails.root, 'db', 'seeds.rb')
  end

  it "runs without error" do
    expect { load(file) }.not_to raise_error
  end
end
