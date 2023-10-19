# frozen_string_literal: true

require 'register_sources_bods/structs/interest'

module RelationshipsHelper
  SUBMISSION_INTEREST_MATCHERS = [
    /^Ownership of shares - [\d.]+%$/,
    /^Ownership of voting rights - ([\d.]+)%$/,
    /^Right to appoint and remove directors$/,
    /^Other \(.+\)$/
  ].freeze

  def known_interests_for(relationship)
    relationship.interests.select(&method(:known_interest?))
  end

  def unknown_interests_for(relationship)
    relationship.interests.reject(&method(:known_interest?))
  end

  def get_most_likely_sample_date(relationship)
    # In the PSC data, we have cases where the `sample_date` is older than the
    # `ended_date`. So for now we need to make a judgement call to use this
    # newer date in place of the stored `sample_date`.

    return relationship.sample_date if relationship.ended_date.blank?
    return nil if relationship.sample_date.blank?
    return relationship.ended_date if relationship.ended_date.to_date > relationship.sample_date.to_date

    relationship.sample_date
  end

  private

  def known_interest?(interest)
    return true if interest.is_a?(Hash) || interest.is_a?(RegisterSourcesBods::Interest)

    I18n.exists?("relationship_interests.#{interest}") || SUBMISSION_INTEREST_MATCHERS.any? { |r| r =~ interest }
  end
end
