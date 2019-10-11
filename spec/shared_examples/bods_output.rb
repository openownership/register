require 'rails_helper'

def libcovebods_missing?
  stdout, _stderr, _status = Open3.capture3('which libcovebods')
  stdout.blank? ? 'No libcovebods found, have you installed it or do you need to activate a venv?' : false
end

RSpec.shared_examples_for 'a well-behaved BODS output' do
  it 'is valid BODS', skip: libcovebods_missing? do
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
