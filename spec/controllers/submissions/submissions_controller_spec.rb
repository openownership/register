require "rails_helper"

RSpec.describe Submissions::SubmissionsController do
  include Devise::Test::ControllerHelpers

  let(:submission) { create(:submission) }

  before do
    sign_in submission.user
  end

  describe "GET #index" do
    let!(:entity) { create(:submission_legal_entity, submission: submission) }

    subject do
      get :index
    end

    it "assigns @submissions" do
      subject
      expect(assigns(:submissions)).to eq([submission])
    end

    it "renders the correct template" do
      subject
      expect(response).to render_template(:index)
    end
  end

  describe "POST #show" do
    subject do
      post :create
    end

    it "creates a submission" do
      expect { subject }.to change { Submissions::Submission.count }.by(1)
    end
  end

  describe "GET #edit" do
    subject do
      get :edit, params: { id: submission.id }
    end

    context "submission is draft" do
      it "renders the correct template" do
        subject
        expect(response).to render_template(:edit)
      end
    end

    context "submission is submitted" do
      before { submission.update_attribute(:submitted_at, 1.minute.ago) }

      it "redirects to show" do
        subject
        expect(response).to redirect_to submission_path(submission)
      end
    end
  end

  describe "GET #show" do
    subject do
      get :show, params: { id: submission.id }
    end

    context "submission is draft" do
      it "redirects to edit" do
        subject
        expect(response).to redirect_to edit_submission_path(submission)
      end
    end

    context "submission is submitted" do
      before { submission.update_attribute(:submitted_at, 1.minute.ago) }

      it "renders the correct template" do
        subject
        expect(response).to render_template(:show)
      end
    end
  end

  describe "POST #submit" do
    let!(:entity) { create(:submission_legal_entity, submission: submission) }

    subject do
      post :submit, params: { id: submission.id }
    end

    it "marks the submission as submitted" do
      subject
      expect(submission.reload.submitted?).to be_truthy
    end

    it "redirects to index" do
      subject
      expect(response).to redirect_to submissions_path
    end

    it "sets a flash notice" do
      subject
      expect(flash[:notice]).to be_present
    end
  end
end
