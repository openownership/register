require "rails_helper"

RSpec.describe Submissions::EntitiesController do
  include Devise::Test::ControllerHelpers
  include SubmissionHelpers

  let(:submission) { FactoryGirl.create(:submission) }

  before do
    sign_in submission.user
  end

  describe "GET #choose" do
    let!(:company) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
    let!(:person) { FactoryGirl.create(:submission_natural_person, submission: submission) }

    subject do
      get :choose, params: { submission_id: submission.id }
    end

    it "assigns @companies_from_submission" do
      subject
      expect(assigns(:companies_from_submission)).to eq([company])
    end

    it "assigns @people_from_submission" do
      subject
      expect(assigns(:people_from_submission)).to eq([person])
    end

    it "renders the correct template" do
      subject
      expect(response).to render_template(:choose)
    end
  end

  describe "GET #new" do
    subject do
      get :new, params: { submission_id: submission.id, entity: { name: "Example" } }
    end

    it "assigns @entity" do
      subject
      expect(assigns(:entity).user_created?).to be_truthy
      expect(assigns(:entity).name).to eq('Example')
    end

    it "renders the correct template" do
      subject
      expect(response).to render_template(:new)
    end
  end

  describe "GET #search" do
    let!(:entity) { FactoryGirl.create(:submission_legal_entity, submission: submission) }

    before do
      stub_opencorporates_api_for_search
    end

    it "assigns @companies_from_submission" do
      get :search, params: { submission_id: submission.id }
      expect(assigns(:companies_from_submission)).to eq([entity])
    end

    it "assigns @companies_from_opencorporates" do
      get :search, params: { submission_id: submission.id, q: "example" }
      expect(assigns(:companies_from_opencorporates)).not_to be_empty
    end

    it "renders the correct template" do
      get :search, params: { submission_id: submission.id }
      expect(response).to render_template(:search)
    end
  end

  describe "POST #use" do
    let(:entity) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
    let(:params) do
      {
        submission_id: submission.id,
        id: entity.id,
      }
    end

    subject do
      post :use, params: params
    end

    it "assigns the correct entity" do
      subject
      expect(assigns(:entity).name).to eq(entity.name)
    end

    context "targeting an entity" do
      let(:target) { FactoryGirl.create(:submission_legal_entity, submission: submission) }

      before do
        params[:target_id] = target.id
      end

      it "creates a relationship" do
        subject

        relationship = Submissions::Relationship.first

        expect(relationship.source.name).to eq(entity.name)
        expect(relationship.target).to eq(target)
      end
    end

    context "inserting an entity" do
      let(:target) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
      let(:source) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
      let!(:relationship) { FactoryGirl.create(:submission_relationship, submission: submission, target: target, source: source) }

      before do
        params[:source_ids] = [source.id]
        params[:target_id] = target.id
      end

      it "destroys the relationship" do
        subject
        expect(relationship.class.all.map(&:id)).not_to include(relationship.id)
      end

      it "creates two new relationships" do
        subject
        expect(relationship.class.count).to be(2)
      end
    end

    it "redirects to edit submission" do
      subject
      expect(response).to redirect_to edit_submission_path(submission)
    end
  end

  describe "POST #create" do
    let(:params) do
      {
        submission_id: submission.id,
        entity: { name: 'Example Entity' },
      }
    end

    subject do
      post :create, params: params
    end

    it "creates an entity" do
      subject
      expect(Submissions::Entity.last.name).to eq('Example Entity')
    end

    context "targeting an entity" do
      let(:target) { FactoryGirl.create(:submission_legal_entity, submission: submission) }

      before do
        params[:target_id] = target.id
      end

      it "creates a relationship" do
        subject

        relationship = Submissions::Relationship.first

        expect(relationship.source.name).to eq('Example Entity')
        expect(relationship.target).to eq(target)
      end
    end

    context "inserting an entity" do
      let(:target) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
      let(:source) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
      let!(:relationship) { FactoryGirl.create(:submission_relationship, submission: submission, target: target, source: source) }

      before do
        params[:source_ids] = [source.id]
        params[:target_id] = target.id
      end

      it "destroys the relationship" do
        subject
        expect(relationship.class.all.map(&:id)).not_to include(relationship.id)
      end

      it "creates two new relationships" do
        subject
        expect(relationship.class.count).to be(2)
      end
    end

    context "dob is invalid" do
      before do
        params[:entity][:type] = Submissions::Entity::Types::NATURAL_PERSON
        params[:entity][:dob] = '2000/02'
      end

      it "validates the date" do
        subject
        expect(assigns(:entity).errors).to include(:dob)
      end
    end
  end

  describe "GET #edit" do
    let(:entity) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
    let(:params) do
      {
        submission_id: submission.id,
        id: entity.id,
      }
    end

    subject do
      get :edit, params: params
    end

    it "assigns the correct entity" do
      subject
      expect(assigns(:entity).name).to eq(entity.name)
    end

    it "renders the correct template" do
      subject
      expect(response).to render_template(:edit)
    end
  end

  describe "PUT #update" do
    let(:entity) { FactoryGirl.create(:submission_legal_entity, submission: submission) }
    let(:params) do
      {
        submission_id: submission.id,
        id: entity.id,
        entity: { name: 'Updated Entity Name' },
      }
    end

    subject do
      put :update, params: params
    end

    it "assigns the correct entity" do
      subject
      expect(assigns(:entity).name).to eq('Updated Entity Name')
    end

    it "redirects to edit submission" do
      subject
      expect(response).to redirect_to edit_submission_path(submission)
    end
  end

  describe "DELETE #destroy" do
    let!(:entity) { FactoryGirl.create(:submission_legal_entity, submission: submission, name: 'Root') }
    let!(:target) { FactoryGirl.create(:submission_legal_entity, submission: submission, name: 'Target') }
    let!(:source) { FactoryGirl.create(:submission_legal_entity, submission: submission, name: 'Source') }
    let!(:relationship_a) { FactoryGirl.create(:submission_relationship, submission: submission, target: entity, source: target) }
    let!(:relationship_b) { FactoryGirl.create(:submission_relationship, submission: submission, target: target, source: source) }

    let(:params) do
      {
        submission_id: submission.id,
        id: source.id,
        relationship_id: relationship_b.id,
      }
    end

    subject do
      delete :destroy, params: params
    end

    it "destroys the relationship" do
      expect { subject }.to change { Submissions::Relationship.count }.by(-1)
    end

    it "creates a new relationship" do
      subject

      relationship = Submissions::Relationship.last

      expect(relationship.source).to eq(target)
      expect(relationship.target).to eq(entity)
    end
  end
end
