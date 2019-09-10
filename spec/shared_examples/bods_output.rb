require 'rails_helper'

RSpec.shared_examples_for 'a well-behaved BODS output' do
  it 'is valid BODS', skip: !ENV.key?('LIB_COVE_BODS') do
    expect(subject).to be_valid_bods
  end

  it 'orders entities before relationships' do
    seen = []
    subject.each do |statement|
      case statement['statementType']
      when 'personStatement', 'entityStatement'
        seen << statement['statementID']
      when 'ownershipOrControlStatement'
        referenced_ids = [
          statement['subject']['describedByEntityStatement'],
          statement['interestedParty'].try('describedByEntityStatement'),
          statement['interestedParty'].try('describedByPersonStatement'),
        ].compact
        expect(seen).to include(*referenced_ids)
      end
    end
  end

  it 'contains all of the expected statements' do
    expect(subject).to match_array(expected_statements)
  end
end
