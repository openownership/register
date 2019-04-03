class DataSource
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug

  field :url, type: String
  field :name, type: String
  slug :name
  field :overview, type: String, localize: true
  field :data_availability, type: String, localize: true
  field :timeline_url, type: String
  field :current_statistic_types, type: Array, default: []

  embeds_many :statistics, class_name: 'DataSourceStatistic'

  index({ name: 1 }, unique: true)

  def statistics_by_type
    statistics.to_a.group_by(&:type)
  end

  def current_statistics
    # Pull out the latest stat for each type we want, preserving the
    # order of current_statistic_types, but putting the total first
    stats_by_type = statistics_by_type
    return [] if stats_by_type.empty?
    stats = current_statistic_types
      .map { |type| stats_by_type[type]&.max_by(&:created_at) }
      .compact
    total_type = DataSourceStatistic::Types::TOTAL
    if stats_by_type[total_type].present?
      stats.prepend(stats_by_type[total_type].max_by(&:created_at))
    end
    stats
  end
end
