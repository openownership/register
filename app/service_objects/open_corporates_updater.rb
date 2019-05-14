class OpenCorporatesUpdater
  def call
    ids_to_update.each { |id| OpenCorporatesUpdateWorker.perform_async(id) }
  end

  private

  def ids_to_update
    Entity
      .where(
        'type' => Entity::Types::LEGAL_ENTITY,
        '$or' => [
          { 'last_resolved_at' => nil },
          { 'last_resolved_at' => { '$lte' => 1.month.ago } },
        ],
      )
      .no_timeout
      .pluck(:id)
  end
end
