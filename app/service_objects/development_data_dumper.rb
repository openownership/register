class DevelopmentDataDumper
  def initialize(dumped_models)
    @dumped_models = dumped_models
  end

  def call
    @dumped_models.each do |klass|
      file = klass.name.tableize
      File.open(Rails.root.join('db', 'data', 'generated', "#{file}.json"), 'w') do |f|
        f.write JSON.pretty_generate(klass.all.as_json)
      end
    end
  end
end
