namespace :migrations do
  desc "Removes _id from all entity identifiers"
  task :simplify_identifiers => :environment do
    Entity.each do |entity|
      entity.update_attribute('identifiers', entity.identifiers.map { |id| id['_id'] || id })
    end
  end
end
