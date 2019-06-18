class DevelopmentDataDumper
  def call
    DevelopmentDataHelper::MODELS.each do |klass|
      file = klass.name.tableize
      File.open(Rails.root.join('db', 'data', 'generated', "#{file}.json"), 'w') do |f|
        f.write JSON.pretty_generate(klass.all.as_json)
      end
    end
  end
end
