class BodsChunkImportRetryWorker < BodsChunkImportWorker
  include Sidekiq::Worker
  sidekiq_options retry: 5

  sidekiq_retries_exhausted do |_msg, ex|
    Rollbar.error(ex, "Retries exhausted whilst trying import chunk")
  end
end
