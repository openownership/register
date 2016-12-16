require 'json'
require 'parallel'

class PscImporter
  def initialize(client: OpencorporatesClient.new)
    @client = client
  end

  def parse(file)
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
    record = JSON.parse(line, symbolize_names: true)

    data = record.fetch(:data)

    case data.fetch(:kind)
    when 'totals#persons-of-significant-control-snapshot'
      :ignore
    when 'persons-with-significant-control-statement'
      :ignore
    when /(individual|corporate-entity|legal-person)-person-with-significant-control/
      company_number = record.fetch(:company_number)

      controlled_entity = controlled_entity!(company_number)

      controlling_entity = controlling_entity!(data)

      Relationship.create!(source: controlling_entity, target: controlled_entity)
    else
      raise "unexpected kind: #{data.fetch(:kind)}"
    end
  end

  def controlled_entity!(company_number)
    response = @client.get_company('gb', company_number)

    corporate_entity!(response)
  end

  def controlling_entity!(data)
    if data.fetch(:kind).start_with?('corporate-entity-person')
      response = get_controlling_entity_company(data.fetch(:identification))

      return corporate_entity!(response) unless response.nil?
    end

    Entity.create!(name: data.fetch(:name))
  end

  def get_controlling_entity_company(identification)
    return if identification[:country_registered].nil?

    jurisdiction_code = @client.get_jurisdiction_code(identification[:country_registered])

    return if jurisdiction_code.nil?

    @client.get_company(jurisdiction_code, identification.fetch(:registration_number))
  end

  def corporate_entity!(response)
    id = identifier(response.fetch(:jurisdiction_code), response.fetch(:company_number))

    Entity.where(identifiers: id).first_or_create!(identifiers: [id], name: response.fetch(:name))
  end

  def identifier(jurisdiction_code, company_number)
    {
      _id: {
        jurisdiction_code: jurisdiction_code,
        company_number: company_number
      }
    }
  end
end
