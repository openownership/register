require 'rails_helper'

RSpec.describe 'resume submission' do
  let(:submission) { create(:submission_legal_entity).submission }

  before do
    login_as submission.user
  end

  scenario 'successfully' do
    visit submissions_path
    click_on submission.entity.name
    expect(page).to have_text(submission_title(submission))
  end

  def submission_title(submission)
    I18n.t('submissions.submissions.instructions_header.started_title_html', entity: submission.entity.name)
  end
end
