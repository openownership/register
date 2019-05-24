namespace :migrations do
  desc "Publish existing PSC statistics"
  task :publish_existing_psc_stats => :environment do
    psc = DataSource.find('uk-psc-register')
    psc.statistics.each { |stat| stat.update_attribute(:published, true) }
  end
end
