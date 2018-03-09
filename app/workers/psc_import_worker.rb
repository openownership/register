class PscImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(source_url)
    retrieved_at = Time.zone.now.to_s
    PscImportTask.new(source_url, retrieved_at).call
  end
end
