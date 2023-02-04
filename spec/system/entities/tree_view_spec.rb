require 'rails_helper'

RSpec.describe 'Tree view' do
  include EntityHelpers

  def expect_root_node_for(entity)
    expect(page).to have_css('.tree-node--root', text: entity.name)
    within('.tree-node--root') do
      expect(page).to have_link entity.name
    end
  end

  def expect_person_node_for(person)
    node = find(".tree-node--natural-person[data-node='#{person.name}']")
    expect(node).not_to be_nil
    within(node) do
      expect(page).to have_link person.name
    end
  end

  def expect_company_node_for(company)
    node = find(".tree-node--legal-entity[data-node='#{company.name}']")
    expect(node).not_to be_nil
    within(node) do
      expect(page).to have_link company.name
    end
  end

  def expect_relationship_link_for(relationship)
    expect(page).to have_css(
      '.tree-node__relationship',
      text: interests_summary(relationship),
    )
  end

  context 'for a simple one person, one company ownership' do
    include_context 'basic entity with one owner'

    it 'shows the owner relationship as a tree' do
      visit tree_entity_path(company)

      expect_person_node_for(person)
      expect_relationship_link_for(relationship)
      expect_root_node_for(company)
    end
  end

  context 'for a company with multiple owners' do
    include_context 'entity with two owners'

    it 'shows both owners' do
      visit tree_entity_path(company)

      expect_person_node_for(person1)
      expect_person_node_for(person2)
      expect_relationship_link_for(relationship1)
      expect_relationship_link_for(relationship2)
      expect_root_node_for(company)
    end
  end

  context 'for an ownership chain with intermediary companies' do
    include_context 'entity with intermediate ownership'

    it 'shows the whole chain for the start company' do
      visit tree_entity_path(start_company)

      expect_person_node_for(ultimate_owner)

      expect_company_node_for(intermediate_company1)
      expect_company_node_for(intermediate_company2)

      expect_relationship_link_for(start_to_intermediate_1_relationship)
      expect_relationship_link_for(intermediate_1_to_intermediate_2_relationship)
      expect_relationship_link_for(intermediate_2_to_owner_relationship)

      expect_root_node_for(start_company)
    end
  end

  context 'for a complex ownership network with multiple owners at different levels' do
    include_context 'entity with ownership at different levels'

    it 'shows the whole network' do
      visit tree_entity_path(start_company)

      expect_person_node_for(ultimate_owner)
      expect_person_node_for(direct_owner)

      expect_company_node_for(intermediate_company)

      expect_relationship_link_for(start_to_direct_owner_relationship)
      expect_relationship_link_for(start_to_intermediate_relationship)
      expect_relationship_link_for(intermediate_to_ultimate_owner_relationship)

      expect_root_node_for(start_company)
    end
  end

  context 'for an ownership chain with no owner at the end' do
    include_context 'entity with no ultimate ownership'

    it 'shows a tree with an unknown owner at the top' do
      visit tree_entity_path(start_company)

      expect(page).to have_css('.tree-node--natural-person', text: 'No person')

      expect_company_node_for(intermediate_company)

      expect_relationship_link_for(start_to_intermediate_relationship)

      expect_root_node_for(start_company)
    end
  end

  context 'for an ownership chain with an unknown ultimate owner' do
    include_context 'entity with unknown ultimate ownership'

    it 'shows a tree with no person at the top' do
      visit tree_entity_path(start_company)

      expect(page).to have_css('.tree-node--natural-person', text: 'Unknown')

      expect_company_node_for(intermediate_company)

      expect_relationship_link_for(start_to_intermediate_relationship)

      expect_root_node_for(start_company)
    end
  end

  context 'for an entity with circular ownership' do
    include_context 'entity with circular ownership'

    it 'shows the circular ownership' do
      visit tree_entity_path(company1)

      expect_company_node_for(company2)

      expect_relationship_link_for(company1_to_company2_relationship)
      expect_relationship_link_for(company2_to_company1_relationship)

      expect(page).to have_css('.tree-node--circular-ownership')

      expect_root_node_for(company1)
    end
  end

  context 'for an entity with circular ownership and an ultimate owner' do
    include_context 'entity with circular ownership and an ultimate owner'

    it 'shows the circular ownership and the ultimate owner' do
      visit tree_entity_path(start_company)

      expect_person_node_for(ultimate_owner)

      expect_company_node_for(intermediate_company)

      expect_relationship_link_for(start_to_intermediate_relationship)
      expect_relationship_link_for(intermediate_to_start_relationship)
      expect_relationship_link_for(intermediate_to_ultimate_owner_relationship)

      expect(page).to have_css('.tree-node--circular-ownership')

      expect_root_node_for(start_company)
    end
  end

  context 'for an entity with a diamond ownership' do
    include_context 'entity with diamond ownership'

    it 'shows the diamond as two separate ownerships' do
      visit tree_entity_path(start_company)

      nodes = all(".tree-node--natural-person[data-node='#{ultimate_owner.name}']")
      expect(nodes.length).to eq(2)
      nodes.each do |node|
        within(node) do
          expect(page).to have_link ultimate_owner.name
        end
      end

      expect_company_node_for(intermediate_company1)
      expect_company_node_for(intermediate_company2)

      expect_relationship_link_for(start_to_intermediate_1_relationship)
      expect_relationship_link_for(start_to_intermediate_2_relationship)
      expect_relationship_link_for(intermediate_1_to_owner_relationship)
      expect_relationship_link_for(intermediate_2_to_owner_relationship)

      expect_root_node_for(start_company)
    end
  end
end
