# frozen_string_literal: true

class ApplicationDecorator < Draper::Decorator
  def self.transliterated_attrs(*attrs)
    Array(attrs).each do |attr|
      define_method(attr) do
        if context[:should_transliterate]
          TransliterationService.for(object.lang_code).transliterate(object.send(attr))
        else
          object.send(attr)
        end
      end
    end
  end
end
