require 'rails_helper'

RSpec.feature 'remove entity' do
  include SubmissionHelpers

  let(:submission) { create(:submission) }
  let!(:root) { create(:submission_legal_entity, submission: submission) }

  before do
    login_as submission.user
  end

  context 'when the entity is ultimate' do
    let(:entity) { create(:submission_natural_person, submission: submission) }

    before do
      create(
        :submission_relationship,
        submission: submission,
        source: entity,
        target: root,
      )
    end

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on remove_entity_button(entity)
      expect(page).not_to have_text entity.name
    end
  end

  context 'when the entity is intermediate' do
    let!(:intermediate) { create(:submission_legal_entity, submission: submission) }

    before do
      create(
        :submission_relationship,
        submission: submission,
        source: intermediate,
        target: root,
      )

      create(
        :submission_relationship,
        submission: submission,
        source: create(:submission_natural_person, submission: submission),
        target: intermediate,
      )

      create(
        :submission_relationship,
        submission: submission,
        source: create(:submission_natural_person, submission: submission),
        target: intermediate,
      )
    end

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on remove_entity_button(intermediate)
      expect(page).not_to have_text intermediate.name
    end
  end

  def remove_entity_button(entity)
    I18n.t('submissions.submissions.tree_node.remove_entity', entity_name: entity.name)
  end
end
