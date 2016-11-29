module PscImporter
  def parse(file)
    entities = []

    file.each_line do |line|
      record = JSON.parse(line, symbolize_names: true)

      data = record.fetch(:data)

      case data.fetch(:kind)
      when 'totals#persons-of-significant-control-snapshot'
        :ignore
      when 'persons-with-significant-control-statement'
        :ignore
      when /(individual|corporate-entity|legal-person)-person-with-significant-control/
        entities << {
          _id: BSON::ObjectId.new,
          name: record.fetch(:company_number)
        }

        entities << {
          _id: BSON::ObjectId.new,
          name: data.fetch(:name)
        }
      else
        raise "unexpected kind: #{data.fetch(:kind)}"
      end
    end

    entities
  end

  module_function :parse
end
