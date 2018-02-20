namespace :entities do
  desc 'Merge two entities - the source entity\'s data will be merged into the target entity and all references updated'
  task :merge, [:to_remove_id, :to_keep_id] => [:environment] do |_task, args|
    to_remove = Entity.find(args.to_remove_id)
    to_keep = Entity.find(args.to_keep_id)
    EntityMerger.new(to_remove, to_keep).call
  end
end
