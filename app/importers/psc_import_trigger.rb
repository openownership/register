class PscImportTrigger
  BASE_URL = 'http://download.companieshouse.gov.uk'.freeze
  DOWNLOAD_PAGE = "#{BASE_URL}/en_pscdata.html".freeze

  FILENAME_REGEX = /^psc-snapshot-\d{4}-\d{2}-\d{2}_\d+of\d+.zip$/

  def call
    snapshot_links = parse_snapshot_links

    raise "No PSC snapshot links found on #{BASE_URL}" if snapshot_links.blank?

    Rails.logger.info "Scheduling PSC import jobs for the following snapshot links: #{snapshot_links}"

    snapshot_links.each { |l| PscImportWorker.perform_async(l) }
  end

  private

  def parse_snapshot_links
    document = Nokogiri::HTML(open(DOWNLOAD_PAGE).read)
    document.css('a').each_with_object([]) do |el, acc|
      href = el['href']
      if href.present? && href.match(FILENAME_REGEX)
        acc << "#{BASE_URL}/#{href}"
      end
    end
  end
end
