namespace :migrations do
  desc "Adds an entity record for OO"
  task :add_oo_entity => :environment do
    oo = Entity.create!(
      name: "Open Ownership",
      type: Entity::Types::LEGAL_ENTITY,
      address: "1199 N. Fairfax St., Suite 300, Alexandria, VA 22314",
      identifiers: [
        {
          document_id: 'manual',
          name: 'Open Ownership',
          sponsor: 'Global Impact',
        },
      ],
    )
    Statement.create!(
      id: { document_id: 'manual', sponsor: 'Global Impact' },
      type: 'open-ownership',
      entity: oo,
    )
    IndexEntityService.new(oo).index
  end
end
