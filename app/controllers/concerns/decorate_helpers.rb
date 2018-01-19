module DecorateHelpers
  extend ActiveSupport::Concern

  # Requires a `should_transliterate` method to be accessible

  def decorate(object)
    if object.is_a?(Enumerable)
      object.map { |o| o.decorate(context: context) }
    else
      object.decorate(context: context)
    end
  end

  def decorate_with(object, decorator_class)
    if object.is_a?(Enumerable)
      decorator_class.decorate_collection(object, context: context)
    else
      decorator_class.new(object, context: context)
    end
  end

  private

  def context
    { should_transliterate: should_transliterate }
  end
end
