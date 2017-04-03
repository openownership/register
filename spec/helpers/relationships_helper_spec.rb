require 'rails_helper'

RSpec.describe RelationshipsHelper do
  describe '#format_interest' do
    it 'uses the translation' do
      expect(helper.format_interest('ownership-of-shares-25-to-50-percent')).to eq(I18n.t('relationship_interests.ownership-of-shares-25-to-50-percent'))
    end

    it 'falls back to a default' do
      expect(helper.format_interest('hello-world', 'fallback')).to eq('fallback')
    end

    it 'returns interests from submissions' do
      a = I18n.t('submissions.relationships.interests.ownership_of_shares_percentage', value: 20.5)
      b = I18n.t('submissions.relationships.interests.voting_rights_percentage', value: 12)
      c = I18n.t('submissions.relationships.interests.right_to_appoint_and_remove_directors')
      d = I18n.t('submissions.relationships.interests.other_significant_influence_or_control', value: 'Hello world')

      expect(helper.format_interest(a)).to eq(a)
      expect(helper.format_interest(b)).to eq(b)
      expect(helper.format_interest(c)).to eq(c)
      expect(helper.format_interest(d)).to eq(d)
    end
  end
end
