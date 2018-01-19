class UltimateSourceRelationshipGroupDecorator < ApplicationDecorator
  delegate_all

  def label
    if context[:should_transliterate]
      TransliterationService.for(object[:label_lang_code]).transliterate(object[:label])
    else
      object[:label]
    end
  end

  def relationships
    @relationships ||= InferredRelationshipDecorator.decorate_collection(object[:relationships], context: context)
  end
end
