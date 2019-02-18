class User
  include Mongoid::Document
  include Timestamps::UpdatedEvenOnUpsert

  field :name, type: String
  field :company_name, type: String
  field :position, type: String

  validates :name, presence: true
  validates :company_name, presence: true
  validates :position, presence: true

  devise :database_authenticatable, :registerable,
         :confirmable, :recoverable, :trackable, :validatable

  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String

  field :confirmation_token,   type: String
  field :confirmed_at,         type: Time
  field :confirmation_sent_at, type: Time
  field :unconfirmed_email,    type: String

  has_many :submissions, class_name: 'Submissions::Submission'
end
