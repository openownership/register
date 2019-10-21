require 'rails_helper'

RSpec.describe UaExtractor do
  it 'writes a config file to the working directory from the template' do
    Dir.mktmpdir do |dir|
      extractor = UaExtractor.new('input.xml', 'output.jsonl', dir)
      allow(extractor).to receive(:system_or_raise_exception).and_return(nil)
      extractor.call
      config = YAML.safe_load(File.read(File.join(dir, 'config.yml')))
      models = config['pipeline']['parser'][1]['voters'].map do |v|
        v[1]['model'] if v.size > 1
      end.compact
      model_path = File.join(dir, 'models').to_s
      models.each { |model| expect(model).to start_with(model_path) }
      expect(config['output_format']).to eq 'jsonl'
      expect(config['export_only_beneficial_owners']).to eq true
    end
  end

  it 'calls the extractor with the config file and input/output files' do
    Dir.mktmpdir do |dir|
      extractor = UaExtractor.new('input.xml', 'output.jsonl', dir)
      config_path = File.join(dir, 'config.yml')
      expected = "ua-edr-extractor #{config_path} --source_xml input.xml --output_file output.jsonl"
      expect(extractor).to receive(:system_or_raise_exception).with(expected).and_return(nil)
      extractor.call
    end
  end
end
