class DataSource
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug

  TYPES = %w[
    selfDeclaration
    officialRegister
    thirdParty
    primaryResearch
    verified
  ].freeze

  field :url, type: String
  field :name, type: String
  slug :name
  field :document_id, type: String
  field :overview, type: String, localize: true
  field :data_availability, type: String, localize: true
  field :timeline_url, type: String
  field :current_statistic_types, type: Array, default: []
  field :types, type: Array, default: []

  embeds_many :statistics, class_name: 'DataSourceStatistic'
  has_many :raw_data_records
  has_many :imports

  validate :validate_types

  index({ name: 1 }, unique: true)

  def statistics_by_type
    statistics.published.to_a.group_by(&:type)
  end

  def current_statistics
    # Pull out the latest stat for each type we want, preserving the
    # order of current_statistic_types
    stats_by_type = statistics_by_type
    return [] if stats_by_type.empty?
    current_statistic_types
      .map { |type| stats_by_type[type]&.max_by(&:created_at) }
      .compact
  end

  def validate_types
    types.each do |type|
      unless TYPES.include? type
        errors.add :types, "#{type} is not a valid DataSource type"
      end
    end
  end
end
