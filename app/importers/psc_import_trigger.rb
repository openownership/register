require 'open-uri'

class PscImportTrigger
  FILENAME_REGEX = /^psc-snapshot-\d{4}-\d{2}-\d{2}_\d+of\d+.zip$/.freeze

  def call(data_source, chunk_size)
    import = Import.create! data_source: data_source
    data_source_uri = URI.parse(data_source.url)
    base_url = "#{data_source_uri.scheme}://#{data_source_uri.host}"
    snapshot_links = parse_snapshot_links(data_source.url, base_url)

    raise "No PSC snapshot links found on #{base_url}" if snapshot_links.blank?

    Rails.logger.info "Scheduling PSC import jobs for the following snapshot links: #{snapshot_links}"

    snapshot_links.each do |link|
      PscFileProcessorWorker.perform_async(link, chunk_size, import.id.to_s)
    end
  end

  private

  def parse_snapshot_links(download_page, base_url)
    document = Nokogiri::HTML(open(download_page).read)
    document.css('a').each_with_object([]) do |el, acc|
      href = el['href']
      if href.present? && href.match(FILENAME_REGEX)
        acc << "#{base_url}/#{href}"
      end
    end
  end
end
