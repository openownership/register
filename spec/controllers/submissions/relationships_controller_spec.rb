require "rails_helper"

RSpec.describe Submissions::RelationshipsController do
  include Devise::Test::ControllerHelpers

  let(:submission) { FactoryGirl.create(:submission) }
  let(:relationship) { FactoryGirl.create(:submission_relationship, submission: submission) }

  before do
    sign_in submission.user
  end

  describe "GET #edit" do
    subject do
      get :edit, params: { submission_id: submission.id, id: relationship.id }
    end

    it "assigns @relationship" do
      subject
      expect(assigns(:relationship)).to eq(relationship)
    end

    it "renders the correct template" do
      subject
      expect(response).to render_template(:edit)
    end
  end

  describe "POST #update" do
    subject do
      post :update, params: { submission_id: submission.id, id: relationship.id, relationship: { voting_rights_percentage: 20.0 } }
    end

    it "assigns @relationship" do
      subject
      expect(assigns(:relationship)).to eq(relationship)
    end

    it "updates the attributes" do
      expect { subject }.to change { relationship.reload.voting_rights_percentage }
    end

    it "redirects" do
      subject
      expect(response).to redirect_to edit_submission_path(submission)
    end
  end
end
