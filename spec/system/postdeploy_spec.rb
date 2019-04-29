require 'rails_helper'

RSpec.describe 'postdeploy task' do
  it 'loads the example data' do
    expect(Entity.count).to eq(0)
    expect(Relationship.count).to eq(0)
    expect(Submissions::Submission.count).to eq(0)
    expect(Submissions::Entity.count).to eq(0)
    expect(Submissions::Relationship.count).to eq(0)
    expect(Statement.count).to eq(0)
    expect(User.count).to eq(0)

    DevelopmentDataLoader.new([
      User,
      Submissions::Submission,
      Submissions::Entity,
      Submissions::Relationship,
      Entity,
      Relationship,
      Statement,
    ]).call

    expect(Entity.count).to eq(4341)
    expect(Relationship.count).to eq(3100)
    expect(Submissions::Submission.count).to eq(9)
    expect(Submissions::Entity.count).to eq(15)
    expect(Submissions::Relationship.count).to eq(6)
    expect(Statement.count).to eq(69)
    expect(User.count).to eq(10)
  end
end
