require 'rails_helper'

RSpec.describe Admin::SubmissionsController do
  include AdminHelpers

  before do
    request.env['HTTP_AUTHORIZATION'] = admin_basic_auth
  end

  let!(:submission) { create(:submitted_submission) }

  describe 'GET #index' do
    before do
      create_list(:submission, 4)
      create(:draft_submission)
      create(:approved_submission)
    end

    it 'assigns only draft, submitted, and approved submissions' do
      get :index
      expect(assigns(:submissions).size).to eq(3)
    end
  end

  describe 'GET #show' do
    it 'assigns @submission' do
      get :show, params: { id: submission.id }
      expect(assigns(:submission)).to eq(submission)
    end

    it 'assigns @entities' do
      get :show, params: { id: submission.id }
      expect(assigns(:entities).size).to eq(2)
    end
  end

  describe 'POST #approve' do
    let(:importer) { instance_double('SubmissionImporter').as_null_object }
    let(:delivery) { instance_double('ActionMailer::MessageDelivery').as_null_object }

    before do
      allow(SubmissionImporter).to receive(:new).and_return(importer)
      allow(SubmissionMailer).to receive(:submission_approved).and_return(delivery)

      post :approve, params: { id: submission.id }
    end

    it 'updates the submission' do
      expect(submission.reload.approved_at).not_to be_nil
    end

    it 'imports the submission' do
      expect(importer).to have_received(:import)
    end

    it 'notifies to the user' do
      expect(delivery).to have_received(:deliver_now)
    end

    it 'redirects' do
      expect(response).to redirect_to(admin_submissions_path)
    end
  end
end
