require 'rails_helper'

RSpec.describe BodsExportRepository do
  subject { described_class.new }

  describe '.most_recent' do
    let!(:old_completed) do
      create(:bods_export, completed_at: '2019-01-01 00:00:00')
    end
    let!(:new_completed) do
      create(:bods_export, completed_at: '2019-01-02 00:00:00')
    end
    let!(:newer_in_progress) do
      create(:bods_export, completed_at: nil)
    end

    it 'returns the most recently completed export' do
      expect(subject.most_recent).to eq(new_completed)
    end
  end
end
