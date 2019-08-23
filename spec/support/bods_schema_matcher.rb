RSpec::Matchers.define :be_valid_bods do
  match do |response|
    file = Tempfile.new('bods.json', '/tmp')
    file.syswrite JSON.dump(response)
    stdout, stderr, = Open3.capture3("#{ENV['LIB_COVE_BODS']} #{file.path}")
    begin
      @validation = JSON.parse(stdout)
    rescue JSON::ParserError => e
      puts "STDOUT: #{stdout}"
      puts "STDERR: #{stderr}"
      raise e
    end
    expect(@validation['validation_errors_count']).to eq 0
  end

  failure_message do
    "BODS validation failed:\n\n#{@validation['validation_errors'].join('\n')}"
  end
end
