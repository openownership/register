module Timestamps
  module UpdatedEvenOnUpsert
    extend ActiveSupport::Concern

    included do
      include Mongoid::Timestamps::Updated

      set_callback :upsert, :before, :set_updated_at
    end
  end
end
