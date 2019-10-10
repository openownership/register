class UaExtractor
  include SystemCallHelper
  attr_accessor :input, :output, :working_dir

  def initialize(input, output, working_dir)
    @input = input
    @output = output
    @working_dir = working_dir
  end

  def call
    write_config
    command = "ua-edr-extractor #{config_file} --source_xml #{@input} --output_file #{@output}"
    system_or_raise_exception(command)
  end

  private

  def write_config
    config_template = Rails.root.join('config', 'ua-edr-extractor.yml.erb')
    config = ERB.new(File.read(config_template)).result(binding)
    File.open(config_file, 'w') { |f| f.write(config) }
  end

  def config_file
    File.join(@working_dir, 'config.yml')
  end
end
