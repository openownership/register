module EntityHelpers
  def interests_summary(relationship)
    if relationship.interests.empty?
      I18n.t("shared.relationship_interests.unknown")
    else
      I18n.t("relationship_interests.#{relationship.interests.first}")
    end
  end

  def birth_month_year(person)
    "#{Date::MONTHNAMES[person.dob.month]} #{person.dob.year}"
  end

  def relationship_href(relationship)
    entity_relationship_path(relationship.target, relationship.source)
  end
end
