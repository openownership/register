module BodsExportHelpers
  def with_temp_output_dir(export)
    export.create_output_folders
    yield export.output_folder
  ensure
    FileUtils.remove_entry_secure(export.output_folder)
  end
end
