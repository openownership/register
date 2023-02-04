class BodsExport
  include Mongoid::Document
  include Mongoid::Timestamps

  field :completed_at, type: Time

  def self.most_recent
    where(:completed_at.ne => nil).order_by(created_at: :desc).first
  end
end
