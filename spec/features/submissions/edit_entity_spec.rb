require 'rails_helper'

RSpec.feature 'edit entity' do
  let(:submission) { create(:submission) }

  before do
    login_as submission.user
    create(
      :submission_relationship,
      submission: submission,
      target: create(:submission_legal_entity, submission: submission),
      source: entity,
    )
  end

  context 'when the entity is a legal entity' do
    let(:entity) { create(:submission_legal_entity, submission: submission, user_created: true) }

    scenario 'successfully' do
      visit edit_submission_path(submission)
      click_on entity.name
      fill_in 'entity_name', with: 'New Company'
      click_on continue_button
      expect(page).to have_link 'New Company'
    end

    def continue_button
      I18n.t('submissions.entities.legal_entity_form.continue')
    end
  end

  context 'when the entity is a natural person' do
    let(:entity) { create(:submission_natural_person, submission: submission, user_created: true) }

    scenario 'successfully' do
      visit edit_submission_path(entity.submission)
      click_on entity.name
      fill_in 'entity_name', with: 'New Person'
      click_on continue_button
      expect(page).to have_link 'New Person'
    end

    def continue_button
      I18n.t('submissions.entities.natural_person_form.continue')
    end
  end
end
