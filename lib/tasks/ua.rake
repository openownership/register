namespace :ua do
  desc 'Download and import latest Ukraine data'
  task :trigger => [:environment] do
    Rails.application.eager_load!
    working_dir = Rails.root.join('tmp/ua-import')
    FileUtils.mkdir_p working_dir
    UaImportTrigger.new(working_dir).call
  end
end
