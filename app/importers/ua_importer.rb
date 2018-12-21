require 'parallel'

class UaImporter
  attr_accessor :source_url, :source_name, :document_id, :retrieved_at

  def initialize(entity_resolver: EntityResolver.new)
    @entity_resolver = entity_resolver
  end

  def parse(file)
    queue = SizedQueue.new(100)

    Thread.abort_on_exception = true
    Thread.new do
      file.each_line do |line|
        queue << line
      end

      queue << Parallel::Stop
    end

    Parallel.each(queue, in_threads: Concurrent.processor_count) do |line|
      begin
        process(line)
      rescue Timeout::Error
        retry
      end
    end
  end

  private

  def process(line)
    record = JSON.parse(line)

    return if !record['Is beneficial owner'] || record['Name'].blank?

    child_entity = child_entity!(record)

    parent_entity = parent_entity!(record)

    relationship!(child_entity, parent_entity, record)
  end

  def child_entity!(record)
    entity = Entity.new(
      lang_code: 'uk',
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => record['Company number'],
        },
      ],
      type: Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: 'ua',
      company_number: record['Company number'],
      name: record['Company name'].presence,
      address: record['Company address'].presence,
    )

    @entity_resolver.resolve!(entity)

    entity.tap(&:upsert)
  end

  def parent_entity!(record)
    attributes = {
      lang_code: 'uk',
      identifiers: [
        {
          'document_id' => document_id,
          'company_number' => record['Company number'],
          'beneficial_owner_id' => record['Name'],
        },
      ],
      type: Entity::Types::NATURAL_PERSON,
      name: record['Name'],
      country_of_residence: record['Country of residence'].presence,
      address: record['Address of residence'].presence,
    }

    Entity.new(attributes).tap(&:upsert)
  end

  def relationship!(child_entity, parent_entity, record)
    attributes = {
      _id: {
        'document_id' => document_id,
        'company_number' => record['Company number'],
        'beneficial_owner_id' => record['Name'],
      },
      source: parent_entity,
      target: child_entity,
      provenance: {
        source_url: source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }

    Relationship.new(attributes).upsert
  end
end
