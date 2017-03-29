require 'rails_helper'

RSpec.describe Submissions::Relationship do
  describe "#interests" do
    context "interests are set" do
      before do
        subject.ownership_of_shares_percentage = 20.0
        subject.voting_rights_percentage = 5.0
        subject.right_to_appoint_and_remove_directors = true
        subject.other_significant_influence_or_control = "test"
      end

      it "formats the interests" do
        expect(subject.interests).to eq(
          [
            "Ownership of shares (20.0%)",
            "Voting rights (5.0%)",
            "Right to appoint and remove directors",
            "Other (test)"
          ]
        )
      end
    end

    context "interests are not set" do
      it "returns an empty array" do
        expect(subject.interests).to eq([])
      end
    end
  end
end
