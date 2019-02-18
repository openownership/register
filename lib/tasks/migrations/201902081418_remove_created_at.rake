namespace :migrations do
  desc "remove created_at timestamps from models where its set"
  task :remove_created_at => :environment do
    models = [
      Entity,
      User,
      Submissions::Entity,
      Submissions::Relationship,
      Submissions::Submission,
    ]
    models.each do |klass|
      Rails.logger.info "Removing created_at for #{klass.name.pluralize}"
      klass.collection.update_many({}, '$unset' => { 'created_at' => true })
    end
  end
end
