require 'rails_helper'

RSpec.describe 'postdeploy task' do
  it 'loads the example data' do
    DevelopmentDataHelper::MODELS.each { |klass| expect(klass.count).to eq(0) }

    DevelopmentDataLoader.new.call

    expect(Entity.count).to eq(4341)
    expect(Relationship.count).to eq(3100)
    expect(Submissions::Submission.count).to eq(9)
    expect(Submissions::Entity.count).to eq(15)
    expect(Submissions::Relationship.count).to eq(6)
    expect(Statement.count).to eq(69)
    expect(User.count).to eq(10)
    expect(DataSource.count).to eq(27)
    expect(Import.count).to eq(1)
    expect(RawDataProvenance.count).to eq(3172)
    expect(RawDataRecord.count).to eq(1113)
  end
end
