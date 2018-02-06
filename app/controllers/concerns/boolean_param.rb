module BooleanParam
  extend ActiveSupport::Concern

  FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF'].to_set

  # <param not provided> --> <default>
  # ?foo --> true
  # ?foo=<one of FALSE_VALUES> --> false
  # ?foo=<any other value> --> true
  def boolean_param(name, default: false)
    if params.key?(name)
      value = params[name]
      value.blank? || !FALSE_VALUES.include?(value)
    else
      default
    end
  end
end
