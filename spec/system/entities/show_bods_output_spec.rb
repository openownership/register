require 'rails_helper'

RSpec.describe 'Entity BODS export' do
  # RSpec's defaults aren't very helpful for seeing diffs in big json files
  original_max_length = nil

  before do
    original_max_length = RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length
    RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 100_000
  end

  after do
    RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = original_max_length
  end

  context 'for a simple one person, one company ownership' do
    include_context 'BODS: basic entity with one owner'

    subject do
      visit entity_path(company, format: :json)
      JSON.parse(page.html)
    end

    it_behaves_like 'a well-behaved BODS output'
  end

  context 'for an company that is part of a chain of relationships' do
    include_context 'BODS: company that is part of a chain of relationships'

    subject do
      visit entity_path(legal_entity1, format: :json)
      JSON.parse(page.html)
    end

    it_behaves_like 'a well-behaved BODS output'
  end

  context 'for an company with no relationships' do
    include_context 'BODS: company with no relationships'

    subject do
      visit entity_path(company, format: :json)
      JSON.parse(page.html)
    end

    it_behaves_like 'a well-behaved BODS output'
  end

  context 'for an company that declares an unknown owner' do
    include_context 'BODS: company that declares an unknown owner'

    subject do
      visit entity_path(company, format: :json)
      JSON.parse(page.html)
    end

    it_behaves_like 'a well-behaved BODS output'
  end
end
