require 'rails_helper'

RSpec.describe Submissions::Submission do
  describe "#draft?" do
    it "returns true when it has not been submitted" do
      expect(subject.draft?).to be_truthy
    end

    it "returns false when it has been submitted" do
      subject.submitted_at = 10.minutes.ago
      expect(subject.draft?).to be_falsey
    end
  end

  describe "#submitted?" do
    it "returns true when it has been submitted" do
      subject.submitted_at = 10.minutes.ago
      expect(subject.submitted?).to be_truthy
    end

    it "returns false when it has not been submitted" do
      expect(subject.submitted?).to be_falsey
    end
  end
end
