# frozen_string_literal: true

class PullRequestNumber
  def self.call
    new.call
  end

  def initialize(from = ENV.fetch('HEROKU_APP_NAME', nil))
    @from = from
  end

  def call
    @from.try(:[], /-(pr-\d+$)/, 1)
  end
end
