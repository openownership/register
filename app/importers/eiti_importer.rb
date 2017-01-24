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
  column 'Reporting Date (Sample date)'
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
  column 'Source URL'
  column 'Confidence in this source (HIGH, MEDIUM, LOW)'

  def initialize(opencorporates_client: OpencorporatesClient.new, entity_resolver: EntityResolver.new)
    @opencorporates_client = opencorporates_client

    @entity_resolver = entity_resolver
  end

  def parse(file, jurisdiction_code:, document_id:)
    @jurisdiction_code = jurisdiction_code

    @document_id = document_id

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

    Relationship.create!(source: parent_entity, target: child_entity, interests: Array(record.mechanism_of_control))
  end

  def child_entity!(record)
    jurisdiction = record.child_jurisdiction

    jurisdiction_code = jurisdiction && @opencorporates_client.get_jurisdiction_code(jurisdiction) || @jurisdiction_code

    entity = @entity_resolver.resolve!(jurisdiction_code: jurisdiction_code, identifier: record.child_identifier, name: record.child_name)

    return entity unless entity.nil?

    find_or_create_entity_with_document_id!(record.child_name)
  end

  def parent_entity!(record)
    unless record.parent_type =~ /^Individual\b/i
      if record.parent_jurisdiction
        jurisdiction_code = @opencorporates_client.get_jurisdiction_code(record.parent_jurisdiction)

        if jurisdiction_code
          entity = @entity_resolver.resolve!(jurisdiction_code: jurisdiction_code, identifier: record.parent_identifier, name: record.parent_name)

          return entity unless entity.nil?
        end
      end
    end

    find_or_create_entity_with_document_id!(record.parent_name)
  end

  def find_or_create_entity_with_document_id!(name)
    name = name.strip

    id = {
      _id: {
        document_id: @document_id,
        name: name
      }
    }

    Entity.where(identifiers: id).first_or_create!(identifiers: [id], name: name)
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

      hash[column.name] = row[column.index]
    end

    OpenStruct.new(hash)
  end
end
