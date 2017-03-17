require 'rails_helper'

RSpec.describe Statement do
  describe '#states_no_psc?' do
    subject { Statement.new(type: type).states_no_psc? }

    context 'when the statement states there is no individual or entity with significant control' do
      let(:type) { 'no-individual-or-entity-with-signficant-control' }

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'when the statement states something else' do
      let(:type) { 'steps-to-find-psc-not-yet-completed' }

      it 'returns false' do
        expect(subject).to be false
      end
    end
  end
end
