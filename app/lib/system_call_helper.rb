module SystemCallHelper
  def system_or_raise_exception(command)
    stdout, stderr, status = Open3.capture3(command)
    raise "#{command} failed with exit code #{status}. stdout: #{stdout}, stderr: #{stderr}" unless status.exitstatus.zero?
  end
end
