require 'rails_helper'

RSpec.describe RelationshipsHelper do
  let(:relationship) { instance_double('Relationship') }
  let(:known_interests) { ['Ownership of shares - 20.0%', 'ownership-of-shares-25-to-50-percent'] }
  let(:unknown_interests) { %w[significant-influence-or-control-as-trust some-other-interest] }

  before do
    allow(relationship).to receive(:interests).and_return(known_interests + unknown_interests)
  end

  describe '#known_interests_for' do
    it 'only includes known interests' do
      expect(helper.known_interests_for(relationship)).to eq(known_interests)
    end
  end

  describe '#unknown_interests_for' do
    it 'only includes unknown interests' do
      expect(helper.unknown_interests_for(relationship)).to eq(unknown_interests)
    end
  end
end
