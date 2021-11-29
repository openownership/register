class UaImportTrigger
  include SystemCallHelper

  def initialize(working_dir)
    @working_dir = working_dir
  end

  def call
    download_models
    raw_data = download_data
    extracted_data = File.join(@working_dir, 'output.jsonl')
    UaExtractor.new(raw_data, extracted_data, @working_dir).call

    importer = UaImporter.new(
      source_url: 'https://data.gov.ua/dataset/1c7f3815-3259-45e0-bdf1-64dca07ddc10',
      source_name: 'Ukraine Consolidated State Registry (Edinyy Derzhavnyj Reestr [EDR])',
      document_id: 'Ukraine EDR',
      retrieved_at: Time.zone.now,
    )

    open(extracted_data) { |f| importer.parse(f) }
  end

  private

  def download_models
    gzip_download = File.join(@working_dir, 'models.tar.gz')
    IO.copy_stream(open(ENV['UA_NER_MODELS']), gzip_download)
    system_or_raise_exception("cd #{@working_dir} && tar -xvf #{gzip_download}")
  end

  def download_data
    # The CKAN api version of the page listed as the source_url
    ckan_url = 'https://data.gov.ua/api/3/action/package_show?id=1c7f3815-3259-45e0-bdf1-64dca07ddc10'
    data_url = URI.open(ckan_url) { |f| JSON.parse(f.read) }['result']['resources'].first['url']
    zip_download = File.join(@working_dir, 'data.zip')
    IO.copy_stream(URI.open(data_url), zip_download)
    system_or_raise_exception("cd #{@working_dir} && unzip -o #{zip_download}")
    Dir.glob("#{@working_dir}/*UFOP*/*XML_EDR_UO*.xml").first
  end
end
