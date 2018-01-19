class TransliterationService
  LANG_CODE_TO_RULE_SETS = {
    'uk' => 'Ukrainian-Latin/BGN',
  }.freeze

  def self.for(lang_code)
    @transliterators ||= {}
    @transliterators[lang_code] = new(lang_code) unless @transliterators.key?(lang_code)
    @transliterators[lang_code]
  end

  def initialize(lang_code)
    @lang_code = lang_code
  end

  def transliterate(value)
    # Return the original value if we have a blank lang code or the lang code is not currently supported for transliteration
    if @lang_code.blank? || !LANG_CODE_TO_RULE_SETS.key?(@lang_code)
      return value
    end

    rule_set.transform(value)
  end

  private

  def rule_set
    rule_set_name = LANG_CODE_TO_RULE_SETS[@lang_code]
    @rule_set ||= TwitterCldr::Transforms::Transformer.get(rule_set_name)
  end
end
