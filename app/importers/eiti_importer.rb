require 'csv'
require 'ostruct'

class EitiImporter
  Column = Struct.new(:index, :heading, :name)

  class ColumnError < StandardError
  end

  def self.columns
    @columns ||= []
  end

  def self.column(heading, name = nil)
    columns << Column.new(columns.size, heading, name)
  end

  column 'ID', :id
  column 'Reporting Date (Sample date)', :reporting_date
  column 'Start Date (if known)'
  column 'End Date (if known)'
  column 'Child company name', :child_name
  column 'Child Company register identifier', :child_identifier
  column 'Child company jurisdiction', :child_jurisdiction
  column 'Parent Entity Name', :parent_name
  column 'Parent Entity jurisdiction', :parent_jurisdiction
  column 'Parent Entity register identifier', :parent_identifier
  column 'Parent Entity Type', :parent_type
  column 'Mechanism of Control', :mechanism_of_control
  column 'Direct or Indirect relationship'
  column 'Ownership share (percentage)'
  column 'Voting percentage'
  column 'Type of Share'
  column 'Source URL', :source_url
  column 'Confidence in this source (HIGH, MEDIUM, LOW)'

  attr_accessor :source_name, :source_jurisdiction_code, :document_id, :retrieved_at

  def initialize(opencorporates_client: OpencorporatesClient.new, entity_resolver: EntityResolver.new)
    @opencorporates_client = opencorporates_client

    @entity_resolver = entity_resolver
  end

  def parse(file)
    lines = file.readlines

    read_headings(lines.shift)

    lines.each do |line|
      process(line)
    end
  end

  private

  def process(line)
    record = read_record(line)

    child_entity = child_entity!(record)

    parent_entity = parent_entity!(record)

    relationship!(child_entity, parent_entity, record)
  end

  def child_entity!(record)
    jurisdiction = record.child_jurisdiction

    jurisdiction_code = jurisdiction && @opencorporates_client.get_jurisdiction_code(jurisdiction) || source_jurisdiction_code

    entity = Entity.new(
      jurisdiction_code: jurisdiction_code,
      company_number: record.child_identifier,
      name: record.child_name,
    )

    entity = @entity_resolver.resolve!(entity)

    return entity unless entity.nil?

    entity_with_document_id!(
      record.child_name,
      Entity::Types::LEGAL_ENTITY,
      jurisdiction_code: jurisdiction_code,
    )
  end

  def parent_entity!(record)
    type = entity_type(record)

    if type == Entity::Types::LEGAL_ENTITY && record.parent_jurisdiction
      jurisdiction_code = @opencorporates_client.get_jurisdiction_code(record.parent_jurisdiction)

      if jurisdiction_code
        entity = Entity.new(
          jurisdiction_code: jurisdiction_code,
          company_number: record.parent_identifier,
          name: record.parent_name,
        )
        entity = @entity_resolver.resolve!(entity)

        return entity unless entity.nil?
      end
    end

    entity_with_document_id!(
      record.parent_name,
      type,
      jurisdiction_code: jurisdiction_code,
    )
  end

  def entity_with_document_id!(name, type, attrs = {})
    attributes = attrs.merge(
      identifiers: [
        {
          'document_id' => document_id,
          'name' => name,
        },
      ],
      type: type,
      name: name,
    )

    Entity.new(attributes).tap(&:upsert)
  end

  def relationship!(child_entity, parent_entity, record)
    attributes = {
      _id: {
        'document_id' => document_id,
        'row_id' => record.id,
      },
      source: parent_entity,
      target: child_entity,
      interests: Array(record.mechanism_of_control),
      sample_date: record.reporting_date.presence,
      provenance: {
        source_url: record.source_url,
        source_name: source_name,
        retrieved_at: retrieved_at,
        imported_at: Time.now.utc,
      },
    }

    Relationship.new(attributes).upsert
  end

  def read_headings(input)
    row = CSV.parse_line(input)

    self.class.columns.each do |column|
      unless row[column.index] == column.heading
        raise ColumnError, "column at index #{column.index} is not #{column.heading.inspect}"
      end
    end
  end

  def read_record(input)
    row = CSV.parse_line(input)

    hash = {}

    self.class.columns.each do |column|
      next if column.name.nil?

      hash[column.name] = row[column.index].try(:strip)
    end

    OpenStruct.new(hash)
  end

  def entity_type(record)
    return Entity::Types::NATURAL_PERSON if record.parent_type =~ /^Individual\b/i

    Entity::Types::LEGAL_ENTITY
  end
end
