RSpec::Matchers.define :be_valid_bods do
  match do |response|
    schema_path = Rails.root.join('vendor', 'bods', 'schema', 'bods-package.json')
    @json_schema_errors = JSON::Validator.fully_validate(
      schema_path.to_s,
      response.body,
    )
    @json_schema_errors.blank?
  end

  failure_message do
    "JSON schema validation failed:\n\n#{@json_schema_errors.join("\n")}"
  end
end
