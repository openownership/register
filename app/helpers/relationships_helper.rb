module RelationshipsHelper
  SUBMISSION_INTEREST_MATCHERS = [
    /^Ownership of shares - [\d\.]+%$/,
    /^Ownership of voting rights - ([\d\.]+)%$/,
    /^Right to appoint and remove directors$/,
    /^Other \(.+\)$/
  ].freeze

  def format_interest(interest, default = '')
    return interest if interest_from_submission?(interest)
    I18n.t(interest, scope: :relationship_interests, default: default)
  end

  private

  def interest_from_submission?(interest)
    SUBMISSION_INTEREST_MATCHERS.any? { |r| r =~ interest }
  end
end
