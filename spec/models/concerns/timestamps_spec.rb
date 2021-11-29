require 'rails_helper'

RSpec.describe Timestamps::UpdatedEvenOnUpsert do
  let(:test_model) do
    Class.new do
      def self.name
        'TestModel'
      end

      include Mongoid::Document
      include Timestamps::UpdatedEvenOnUpsert

      field :test_field, type: String
    end
  end

  let(:test_instance) { test_model.new(_id: 'test', test_field: 'test') }

  it "doesn't set updated_at until the instance is persisted" do
    expect(test_instance.updated_at).to be nil
  end

  context 'when you call #save on the including model' do
    # These are essentially non-exhaustive tests that we've included the
    # Mongoid::Timestamps::Updated concern correctly via our concern

    it 'persists updated_at on first save' do
      test_instance.save!
      expect(test_model.find('test').updated_at).to be_within(1.second).of Time.now.utc
    end

    it 'sets updated_at on the instance after first save' do
      test_instance.save!
      expect(test_instance.updated_at).to be_within(1.second).of Time.now.utc
    end

    it "changes updated_at on future saves" do
      test_instance.save!
      original_updated_at = test_instance.updated_at
      test_instance.test_field = 'updated'
      test_instance.save!
      expect(test_instance.updated_at).not_to eq(original_updated_at)
    end
  end

  context 'when you call #upsert on the including model' do
    context 'and the upsert results in an insert' do
      it 'persists updated_at' do
        test_instance.upsert
        expect(test_model.find('test').updated_at).to be_within(1.second).of Time.now.utc
      end

      it 'sets updated_at on the instance' do
        test_instance.upsert
        expect(test_instance.updated_at).to be_within(1.second).of Time.now.utc
      end
    end

    context 'and the upsert results in an update' do
      it "changes updated_at" do
        test_instance.save!
        original_updated_at = test_instance.updated_at
        test_instance.test_field = 'updated'
        test_instance.upsert
        expect(test_instance.updated_at).not_to eq(original_updated_at)
      end
    end
  end
end
