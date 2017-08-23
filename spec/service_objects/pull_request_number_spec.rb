require 'rails_helper'

RSpec.describe PullRequestNumber do
  describe '.call' do
    before do
      allow_any_instance_of(described_class)
        .to receive(:call)
        .and_return 'called'
    end

    it 'calls `call` on instance' do
      expect(described_class.call).to eq 'called'
    end
  end

  context 'when on Heroku' do
    subject { described_class.new('oo--pr-13') }

    it 'returns the PR number' do
      expect(subject.call).to eq 'pr-13'
    end

    context 'when input is potentially confusing' do
      subject { described_class.new('pr-pr--pr-13') }

      it 'returns the PR number' do
        expect(subject.call).to eq 'pr-13'
      end
    end
  end

  context 'when not on Heroku' do
    subject { described_class.new(nil) }

    it 'returns nil' do
      expect(subject.call).to eq nil
    end
  end
end
