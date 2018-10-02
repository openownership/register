require 'rails_helper'

RSpec.describe SearchesController do
  describe 'GET #show' do
    context 'with an empty search index' do
      let(:query) { 'foo' }

      before do
        Entity.import(force: true, refresh: true)
      end

      it 'should not have any search results' do
        get :show, params: { q: query }
        expect(assigns(:response).results.total).to be 0
      end

      it 'should have attempted a fallback' do
        get :show, params: { q: query }
        expect(assigns(:fallback)).to be true
      end
    end

    context 'with data in the search index' do
      let!(:entities) do
        [
          'ABC inc',
          'Best Food LTD',
          'Best Clothes',
          'Best Super Glue Inc',
          'Best Super Glue ltd',
        ].map { |n| create :legal_entity, name: n }
      end

      before do
        Entity.import(force: true, refresh: true)
      end

      it 'finds a direct match' do
        get :show, params: { q: 'ABC inc' }
        expect(assigns(:response).records.to_a).to eq [entities[0]]
        expect(assigns(:fallback)).to be false
      end

      it 'finds a direct match even when other closely named companies exist' do
        get :show, params: { q: 'Best Food LTD' }
        expect(assigns(:response).records.to_a).to eq [entities[1]]
        expect(assigns(:fallback)).to be false
      end

      it 'finds a match even with one word phrases' do
        get :show, params: { q: 'food' }
        expect(assigns(:response).records.to_a).to eq [entities[1]]
        expect(assigns(:fallback)).to be false
      end

      it 'does not do partial word matches' do
        get :show, params: { q: 'Bes' }
        expect(assigns(:response).records.to_a).to eq []
        expect(assigns(:fallback)).to be true
      end

      it 'ignores certain terms like \'ltd\' and \'inc\' in a case-insensitive fashion' do
        get :show, params: { q: 'Best Super Glue inc' }
        expect(assigns(:response).records.to_a).to match_array [entities[3], entities[4]]
        expect(assigns(:fallback)).to be false
      end

      it 'finds a match even with another other word in between' do
        get :show, params: { q: 'Best Glue' }
        expect(assigns(:response).records.to_a).to match_array [entities[3], entities[4]]
        expect(assigns(:fallback)).to be false
      end

      it 'falls back to a broader search when no direct matches have been found' do
        get :show, params: { q: 'Best Cars Eva' }
        expect(assigns(:response).records.to_a).to match_array [entities[1], entities[2], entities[3], entities[4]]
        expect(assigns(:fallback)).to be true
      end
    end
  end
end
