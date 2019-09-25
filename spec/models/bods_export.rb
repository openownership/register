require 'rails_helper'

RSpec.describe BodsExport do
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
      expect(BodsExport.most_recent).to eq(new_completed)
    end
  end
end
