class ModelExport
  include Enumerable

  def initialize(model)
    @model = model
  end

  def each
    @model.each do |record|
      yield(record.to_builder.target!)
    end
  end

  def name
    @model.to_s.underscore.pluralize
  end
end
