require 'rails_helper'

RSpec.describe 'postdeploy task' do
  it 'loads the example data' do
    OpenOwnershipRegister::Application.load_tasks
    Rake::Task['postdeploy'].invoke

    expect(Entity.count).to eq(4341)
    expect(Relationship.count).to eq(3100)
    expect(Submissions::Submission.count).to eq(9)
    expect(Submissions::Entity.count).to eq(15)
    expect(Submissions::Relationship.count).to eq(6)
    expect(Statement.count).to eq(69)
    expect(User.count).to eq(10)
  end
end
