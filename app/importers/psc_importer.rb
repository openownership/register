require 'json'
require 'parallel'

class PscImporter
  def initialize(opencorporates_client: OpencorporatesClient.new, entity_resolver: EntityResolver.new)
    @opencorporates_client = opencorporates_client

    @entity_resolver = entity_resolver
  end

  def parse(file, document_id:)
    @document_id = document_id

    queue = SizedQueue.new(100)

    Thread.new do
      file.each_line do |line|
        queue << line
      end

      queue << Parallel::Stop
    end

    Parallel.each(queue, in_threads: 20) do |line|
      process(line)
    end
  end

  private

  def process(line)
    record = JSON.parse(line, symbolize_names: true, object_class: OpenStruct)

    case record.data.kind
    when 'totals#persons-of-significant-control-snapshot'
      :ignore
    when 'persons-with-significant-control-statement'
      :ignore
    when /(individual|corporate-entity|legal-person)-person-with-significant-control/
      child_entity = @entity_resolver.resolve!(jurisdiction_code: 'gb', identifier: record.company_number, name: nil)

      parent_entity = parent_entity!(record.data)

      Relationship.create!(source: parent_entity, target: child_entity, interests: record.data.natures_of_control)
    else
      raise "unexpected kind: #{data.fetch(:kind)}"
    end
  end

  def parent_entity!(data)
    if data.kind.start_with?('corporate-entity-person')
      country = data.identification.country_registered

      unless country.nil?
        jurisdiction_code = @opencorporates_client.get_jurisdiction_code(country)

        unless jurisdiction_code.nil?
          identifier = data.identification.registration_number

          name = data.name

          entity = @entity_resolver.resolve!(jurisdiction_code: jurisdiction_code, identifier: identifier, name: name)

          return entity unless entity.nil?
        end
      end
    end

    find_or_create_entity_with_document_id!(data)
  end

  def find_or_create_entity_with_document_id!(data)
    id = {
      _id: {
        document_id: @document_id,
        link: data.links.self
      }
    }

    begin
      Entity.where(identifiers: id).first_or_create!(identifiers: [id], name: data.name)
    rescue Mongo::Error::OperationFailure => e
      raise unless e.message =~ /\bE11000\b/
      retry
    end
  end
end
