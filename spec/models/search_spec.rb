require 'rails_helper'

RSpec.describe Search do
  describe '.query' do
    let(:search_params) do
      {
        q: 'smith',
      }
    end

    subject { Search.query(search_params) }

    it 'includes a match query for the name field' do
      match_query = {
        match_phrase: {
          name: {
            query: 'smith',
            slop: 50,
          },
        },
      }

      expect(subject[:bool][:should]).to include(match_query)
    end

    it 'includes a match query for the name_transliterated field' do
      match_query = {
        match_phrase: {
          name_transliterated: {
            query: 'smith',
            slop: 50,
          },
        },
      }

      expect(subject[:bool][:should]).to include(match_query)
    end

    it 'should match on either the name or name_transliterated fields, or both' do
      expect(subject[:bool][:minimum_should_match]).to eq 1
    end

    context 'when excluded terms are present' do
      let(:search_params) do
        {
          q: 'foolimited bar inc',
        }
      end

      it 'removes only whole matched excluded terms' do
        expect(subject[:bool][:should].first[:match_phrase][:name][:query]).to eq 'foolimited bar '
      end
    end

    context 'when the type param is present' do
      let(:search_params) do
        {
          type: Entity::Types::NATURAL_PERSON,
        }
      end

      it 'includes a term query filter for the type field' do
        filter = {
          term: {
            type: Entity::Types::NATURAL_PERSON,
          },
        }

        expect(subject[:bool][:filter]).to include(filter)
      end
    end

    context 'when the country param is present' do
      let(:search_params) do
        {
          country: 'GB',
        }
      end

      it 'includes a term query filter for the country_code field' do
        filter = {
          term: {
            country_code: 'GB',
          },
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
