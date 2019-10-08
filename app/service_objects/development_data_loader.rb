class DevelopmentDataLoader
  def call
    DevelopmentDataHelper::MODELS.each do |klass|
      file = klass.name.tableize
      data = File.read(Rails.root.join('db', 'data', 'generated', "#{file}.json"))
      JSON.parse(data).each do |instance_data|
        if klass == User
          # We have to manually set the password and confirmed_at for users, devise
          # won't dump it
          instance_data[:confirmed_at] = Time.zone.now
          instance_data[:password] = ENV.fetch('ADMIN_BASIC_AUTH').split(":").last
        end

        # Mongo doesn't mongoize $oid fields outside of foreign keys and normal id
        # fields so we need to do it ourselves for identifiers and ids which come from
        # submissions
        if klass == Entity
          instance_data['identifiers'].each do |identifier|
            next unless identifier.is_a?(Hash)

            identifier.each do |key, value|
              identifier[key] = BSON::ObjectId.from_string(value['$oid']) if value['$oid']
            end
          end
        end

        if klass == Relationship && instance_data['_id'].is_a?(Hash)
          instance_data['_id'].each do |key, value|
            instance_data['_id'][key] = BSON::ObjectId.from_string(value['$oid']) if value['$oid']
          end
        end

        klass.create!(instance_data)
      end
    end

    Entity.import(force: true)
  end
end
