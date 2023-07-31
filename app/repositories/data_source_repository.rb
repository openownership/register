require 'register_sources_psc/structs/company_record'
require 'register_sources_dk/structs/record'
require 'register_sources_sk/structs/record'

class DataSourceRepository
  def all
    path = File.join(File.dirname(__FILE__), 'datasources.json')
    sources = JSON.parse(File.read(path), symbolize_names: true)
    
    sources[:datasources].map { |source|
      DataSource.new source.merge(id: source[:'_id'][:'$oid'])
    }
  end

  def find(id)
    find_many([id])[0]
  end

  def find_many(ids)
    all.filter { |data_source| ids.include? data_source.id }
  end

  def where_overview_present
    all.filter { |data_source| data_source.overview.present? }
  end

  def data_source_names_for_raw_records(raw_records)
    datasource_names = raw_records.map do |raw_record|
      case raw_record
      when RegisterSourcesDk::Deltagerperson
        "Denmark Central Business Register (Centrale Virksomhedsregister [CVR])"
      when RegisterSourcesPsc::CompanyRecord
        "UK PSC Register"
      when RegisterSourcesSk::Record
        "Slovakia Public Sector Partners Register (Register partnerov verejného sektora)"
      end
    end.compact.uniq.sort
  end

  def all_for_raw_records(raw_records)
    datasource_names = data_source_names_for_raw_records(raw_records)

    all.filter { |data_source| datasource_names.include? data_source.name }
  end
end
