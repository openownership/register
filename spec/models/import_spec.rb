require 'rails_helper'

RSpec.describe Import do
  describe '.all_for_entity' do
    let!(:entity) { create(:legal_entity) }
    let!(:imports) { create_list(:import, 3) }
    let!(:raw_data_provenances) do
      imports.drop(1).map do |import|
        create(
          :raw_data_provenance,
          entity_or_relationship: entity,
          import: import,
        )
      end
    end

    it 'returns all the imports an entity is connected to by raw data' do
      expect(Import.all_for_entity(entity)).to match_array(imports.drop(1))
    end

    it "doesn't return duplicate imports" do
      create(
        :raw_data_provenance,
        entity_or_relationship: entity,
        import: imports[1],
      )
      expect(Import.all_for_entity(entity)).to match_array(imports.drop(1))
    end
  end
end
