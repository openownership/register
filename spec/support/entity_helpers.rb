module EntityHelpers
  def ownership_summary(relationship)
    I18n.t("relationship_interests.#{relationship.interests.first}")
  end

  def birth_month_year(person)
    "#{Date::MONTHNAMES[person.dob.month]} #{person.dob.year}"
  end
end
