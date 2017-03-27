require 'iso8601'

module ISO8601
  class Date
    def mongoize
      @original
    end

    def self.demongoize(string)
      return unless string.present?

      new(string)
    end
  end
end
