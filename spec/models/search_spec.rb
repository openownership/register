require 'rails_helper'

RSpec.describe Search do
  describe '.query' do
    let(:search_params) do
      {
        q: 'smith'
      }
    end

    subject { Search.query(search_params) }

    it 'includes a match query for the name' do
      match_query = {
        match: {
          name: {
            query: 'smith',
            operator: 'AND'
          }
        }
      }

      expect(subject[:bool][:must]).to include(match_query)
    end

    context 'when the type param is present' do
      let(:search_params) do
        {
          type: Entity::Types::NATURAL_PERSON
        }
      end

      it 'includes a term query filter for the type field' do
        filter = {
          term: {
            type: Entity::Types::NATURAL_PERSON
          }
        }

        expect(subject[:bool][:filter]).to include(filter)
      end
    end

    context 'when the country param is present' do
      let(:search_params) do
        {
          country: 'GB'
        }
      end

      it 'includes a term query filter for the country_code field' do
        filter = {
          term: {
            country_code: 'GB'
          }
        }

        expect(subject[:bool][:filter]).to include(filter)
      end
    end
  end

  describe '.aggregations' do
    subject { Search.aggregations }

    it 'includes a terms aggregation for the type field' do
      expect(subject[:type][:terms][:field]).to eq(:type)
    end

    it 'includes a terms aggregation for the country_code field' do
      expect(subject[:country][:terms][:field]).to eq(:country_code)
    end
  end
end
