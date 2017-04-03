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
            I18n.t('submissions.relationships.interests.ownership_of_shares_percentage', value: 20.0),
            I18n.t('submissions.relationships.interests.voting_rights_percentage', value: 5.0),
            I18n.t('submissions.relationships.interests.right_to_appoint_and_remove_directors'),
            I18n.t('submissions.relationships.interests.other_significant_influence_or_control', value: 'test')
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
