require 'rails_helper'

RSpec.describe Submissions::EntitiesHelper do
  describe '#countries_for_select' do
    subject { helper.countries_for_select }

    it 'returns the options' do
      expect(subject).to include(
        %w(Argentina ar),
        ['United Kingdom', 'gb'],
      )
    end

    it 'sorts alphabetically' do
      uk_index = subject.index(['United Kingdom', 'gb'])
      th_index = subject.index(%w(Thailand th))

      expect(uk_index).to be > th_index
    end
  end

  describe '#jurisdictions_for_select' do
    subject { helper.jurisdictions_for_select("us_me") }

    it 'sorts alphabetically' do
      uk_index = subject.index('United Kingdom')
      th_index = subject.index('Thailand')

      expect(uk_index).to be > th_index
    end

    it 'includes jurisdictions' do
      expect(subject).to match(/<option value=\"ar\">Argentina/)
      expect(subject).to match(/<option value=\"ca\">Canada/)
    end

    it 'groups subjurisdictions' do
      expect(subject).to match(/<optgroup label=\"Canada\">/)
      expect(subject).to match(/<optgroup label=\"United States\">/)
    end

    it 'includes subjurisdictions' do
      expect(subject).to match(/<option value=\"ca_qc\">/)
      expect(subject).to match(/<option value=\"us_ny\">/)
    end

    it "sets default value" do
      expect(subject).to match(/<option selected="selected" value="us_me">/)
    end
  end

  describe '#form_options_for_entity' do
    subject { helper.form_options_for_entity(entity) }

    let(:submission) { instance_double('Submissions::Submission', id: '123', to_param: '123') }
    let(:entity) { instance_double('Submissions::Entity', submission: submission, id: '456', to_param: '456') }

    context 'entity is new' do
      before { allow(entity).to receive(:persisted?).and_return(false) }

      it 'returns options for create form' do
        expect(subject).to eq(
          url: submission_entities_path(entity.submission.id),
          method: :post,
        )
      end
    end

    context 'entity is persisted' do
      before { allow(entity).to receive(:persisted?).and_return(true) }

      it 'returns options for update form' do
        expect(subject).to eq(
          url: submission_entity_path(entity.submission.id, entity.id),
          method: :put,
        )
      end
    end
  end
end
