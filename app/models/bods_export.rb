class BodsExport
  include Mongoid::Document
  include Mongoid::Timestamps

  field :completed_at, type: Time

  # The Redis set where we store our all-time set of statement ids
  # for skipping statements that already exist
  REDIS_ALL_STATEMENTS_SET = 'bods-export-redis-statements-set'.freeze
  # The Redis list where we store the list of statement ids from this export
  # for maintaining a consistent ordering of statements
  REDIS_ALL_STATEMENTS_LIST = 'bods-export-redis-statements-list'.freeze

  def self.most_recent
    where(:completed_at.ne => nil).order_by(created_at: :desc).first
  end

  def self.redis_all_statements_set
    ENV['BODS_EXPORT_REDIS_STATEMENTS_SET']
  end

  def redis_statements_list
    "#{REDIS_ALL_STATEMENTS_LIST}:#{id}"
  end

  def output_folder
    Rails.root.join('tmp/exports', id.to_s)
  end

  def statements_folder
    File.join(output_folder, 'statements')
  end

  def statement_filename(statement_id)
    hash = statement_id.gsub(BodsMapper::ID_PREFIX, '')
    File.join(statements_folder, hash[0], hash[1], hash[2], "#{statement_id}.json")
  end

  def create_output_folders
    (0..9).each do |i|
      (0..9).each do |j|
        (0..9).each do |k|
          FileUtils.mkdir_p File.join(statements_folder, i.to_s, j.to_s, k.to_s)
        end
      end
    end
  end
end
