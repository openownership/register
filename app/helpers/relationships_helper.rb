module RelationshipsHelper
  SUBMISSION_INTEREST_MATCHERS = [
    /^Ownership of shares - [\d\.]+%$/,
    /^Ownership of voting rights - ([\d\.]+)%$/,
    /^Right to appoint and remove directors$/,
    /^Other \(.+\)$/
  ].freeze

  def known_interests_for(relationship)
    relationship.interests.select(&method(:known_interest?))
  end

  def unknown_interests_for(relationship)
    relationship.interests.reject(&method(:known_interest?))
  end

  private

  def known_interest?(interest)
    I18n.exists?("relationship_interests.#{interest}") || SUBMISSION_INTEREST_MATCHERS.any? { |r| r =~ interest }
  end
end
