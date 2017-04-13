require 'rails_helper'

RSpec.describe RelationshipGraph do
  def entities
    @entities ||= []
  end

  def entity!(identifier, name, type = Entity::Types::LEGAL_ENTITY)
    id = {
      _id: {
        'identifier' => identifier,
      },
    }

    entity = Entity.where(identifiers: id).first_or_create!(identifiers: [id], type: type, name: name)

    entities << entity

    entity
  end

  def relationships!
    entities.each_cons(2) do |(target, source)|
      create(:relationship, target: target, source: source)
    end
  end

  describe '#ultimate_source_relationships' do
    it 'returns an array of ultimate source relationships for the entity' do
      entity!('07711111', 'FLAGSTAFF 1 LIMITED')
      entity!('03487308', 'TRILLIUM HOLDINGS LIMITED')
      entity!('06761256', 'LONDON WALL OUTSOURCING LIMITED')
      entity!('08788866', 'LONDON WALL OUTSOURCING FREEHOLDS LIMITED')
      entity!('09335291', 'TELEREAL (LONDON WALL) LIMITED')
      entity!('08787339', 'LONDON WALL OUTSOURCING INVESTMENTS LIMITED')
      entity!('person1', 'A Person', Entity::Types::NATURAL_PERSON)

      relationships!

      relationships = RelationshipGraph.new(entities.first).ultimate_source_relationships

      expect(relationships).to be_an(Array)
      expect(relationships.size).to eq(1)
      expect(relationships.first).to be_a(InferredRelationship)
      expect(relationships.first.source).to eq(entities.last)
      expect(relationships.first.target).to eq(entities.first)
    end

    context 'when the entity has no direct target relationships' do
      it 'returns no relationships' do
        entity!('person1', 'A Person', Entity::Types::NATURAL_PERSON)

        relationships = RelationshipGraph.new(entities.first).ultimate_source_relationships

        expect(relationships).to be_empty
      end
    end

    context 'when there are multiple relationships leading to the same ultimate source entity' do
      it 'returns all the relationships' do
        entity_a = entity!('person1', 'A Person', Entity::Types::NATURAL_PERSON)
        entity_b = entity!('0000000B', 'B')
        entity_c = entity!('0000000C', 'C')
        entity_d = entity!('0000000D', 'D')

        create(:relationship, target: entity_b, source: entity_a)
        create(:relationship, target: entity_c, source: entity_a)
        create(:relationship, target: entity_d, source: entity_b)
        create(:relationship, target: entity_d, source: entity_c)

        relationships = RelationshipGraph.new(entity_d).ultimate_source_relationships

        expect(relationships.size).to eq(2)
        expect(relationships[0].source).to eq(entity_a)
        expect(relationships[0].target).to eq(entity_d)
        expect(relationships[1].source).to eq(entity_a)
        expect(relationships[1].target).to eq(entity_d)
      end
    end

    context 'when there is a circular loop within the relationship chain' do
      it 'returns the relationship to the ultimate source entity' do
        entity!('04581669', 'LUMINUS DEVELOPMENTS LIMITED')
        entity!('06438705', 'LUMINUS FINANCE LIMITED')
        entity!('04782653', 'LUMINUS GROUP LIMITED')
        entity!('03736718', 'LUMINUS HOMES LIMITED')
        entity!('04782653', 'LUMINUS GROUP LIMITED')

        relationships!

        entity = Entity.create!(name: 'A Person', type: Entity::Types::NATURAL_PERSON)

        create(:relationship, target: entities[-2], source: entity)

        relationships = RelationshipGraph.new(entities.first).ultimate_source_relationships

        expect(relationships.size).to eq(1)
        expect(relationships.first.source).to eq(entity)
        expect(relationships.first.target).to eq(entities.first)
      end
    end

    context 'when there is a circular loop at the top of the relationship chain' do
      it 'returns no relationships' do
        entity!('0000000A', 'A')
        entity!('0000000B', 'B')
        entity!('0000000C', 'C')
        entity!('0000000B', 'B')

        relationships!

        relationships = RelationshipGraph.new(entities.first).ultimate_source_relationships

        expect(relationships).to be_empty
      end
    end
  end

  describe '#relationships_to' do
    context 'when there is a direct relationship between the subject entity and the given entity' do
      it 'returns an array containing the direct relationship' do
        entity!('07711112', 'FLAGSTAFF 3 LIMITED')
        entity!('2106', 'BANK OF N.T. BUTTERFIELD & SON LIMITED (THE)')

        relationships!

        relationships = RelationshipGraph.new(entities.first).relationships_to(entities.last)

        expect(relationships).to be_an(Array)
        expect(relationships.size).to eq(1)
        expect(relationships.first.source).to eq(entities.last)
        expect(relationships.first.target).to eq(entities.first)
      end

      context 'when the given entity is not an ultimate source entity' do
        it 'returns an array containing the direct relationship' do
          entity!('0000000A', 'A')
          entity = entity!('0000000B', 'B')
          entity!('0000000C', 'C')

          relationships!

          relationships = RelationshipGraph.new(entities.first).relationships_to(entity)

          expect(relationships).to be_an(Array)
          expect(relationships.size).to eq(1)
          expect(relationships.first.source).to eq(entity)
          expect(relationships.first.target).to eq(entities.first)
        end
      end
    end

    context 'when there is an indirect relationship between the subject entity and the given entity' do
      it 'returns an array containing the indirect relationship' do
        entity!('07711111', 'FLAGSTAFF 1 LIMITED')
        entity!('03487308', 'TRILLIUM HOLDINGS LIMITED')
        entity!('06761256', 'LONDON WALL OUTSOURCING LIMITED')
        entity!('08788866', 'LONDON WALL OUTSOURCING FREEHOLDS LIMITED')
        entity!('09335291', 'TELEREAL (LONDON WALL) LIMITED')
        entity!('08787339', 'LONDON WALL OUTSOURCING INVESTMENTS LIMITED')
        entity!('2106', 'BANK OF N.T. BUTTERFIELD & SON LIMITED (THE)')

        relationships!

        2.upto(6) do |index|
          entity = entities[index]

          relationships = RelationshipGraph.new(entities.first).relationships_to(entity)

          expect(relationships).to be_an(Array)
          expect(relationships.size).to eq(1)
          expect(relationships.first.source).to eq(entity)
          expect(relationships.first.target).to eq(entities.first)
          expect(relationships.first.sourced_relationships.size).to eq(index)
        end
      end
    end

    context 'when there are multiple relationships between the subject entity and the given entity' do
      it 'returns an array containing all the relationships' do
        entity_a = entity!('0000000A', 'A')
        entity_b = entity!('0000000B', 'B')
        entity_c = entity!('0000000C', 'C')
        entity_d = entity!('0000000D', 'D')

        create(:relationship, target: entity_b, source: entity_a)
        create(:relationship, target: entity_c, source: entity_a)
        create(:relationship, target: entity_d, source: entity_b)
        create(:relationship, target: entity_d, source: entity_c)

        relationships = RelationshipGraph.new(entities.last).relationships_to(entities.first)

        expect(relationships).to be_an(Array)
        expect(relationships.size).to eq(2)
        expect(relationships[0].source).to eq(entity_a)
        expect(relationships[0].target).to eq(entity_d)
        expect(relationships[1].source).to eq(entity_a)
        expect(relationships[1].target).to eq(entity_d)
      end
    end

    context 'when there is a circular loop between the subject entity and the given entity' do
      it 'returns an array containing all the relationships' do
        entity!('04581669', 'LUMINUS DEVELOPMENTS LIMITED')
        entity!('06438705', 'LUMINUS FINANCE LIMITED')
        entity!('04782653', 'LUMINUS GROUP LIMITED')
        entity!('03736718', 'LUMINUS HOMES LIMITED')
        entity!('04782653', 'LUMINUS GROUP LIMITED')

        relationships!

        relationships = RelationshipGraph.new(entities.first).relationships_to(entities.last)

        expect(relationships).to be_an(Array)
        expect(relationships.size).to eq(2)
        expect(relationships[0].source).to eq(entities.last)
        expect(relationships[0].target).to eq(entities.first)
        expect(relationships[1].source).to eq(entities.last)
        expect(relationships[1].target).to eq(entities.first)
      end
    end

    context 'when there are no relationships between the entity and the given source entity' do
      it 'returns an empty array' do
        entity!('07711112', 'FLAGSTAFF 3 LIMITED')
        entity!('2106', 'BANK OF N.T. BUTTERFIELD & SON LIMITED (THE)')

        relationships = RelationshipGraph.new(entities.first).relationships_to(entities.last)

        expect(relationships).to eq([])
      end
    end
  end
end
