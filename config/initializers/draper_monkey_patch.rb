require 'draper/query_methods/load_strategy'

module Draper
  module QueryMethods
    module LoadStrategy
      class ActiveRecord
        def allowed?(_method)
          # Original in draper v4.0.2 is:
          #   ::ActiveRecord::Relation::VALUE_METHODS.include? method
          # This errors in projects not using ActiveRecord with undefined constant ::ActiveRecord
          false
        end
      end
    end
  end
end
