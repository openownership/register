require 'rails_helper'

RSpec.feature "seeds" do
  let(:file) do
    File.join(Rails.root, 'db', 'seeds.rb')
  end

  it "runs" do
    load(file)
  end
end
