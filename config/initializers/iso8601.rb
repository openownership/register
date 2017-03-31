require 'iso8601'

module ISO8601
  class Date
    def mongoize
      @original
    end

    def self.mongoize(object)
      case object
      when Date
        object.mongoize
      when String
        Date.new(object).mongoize
      when NilClass
        nil
      else
        raise "Unable to mongoize #{object.class.name} #{object} as #{name}"
      end
    end

    def self.demongoize(string)
      return unless string.present?

      new(string)
    end
  end
end
