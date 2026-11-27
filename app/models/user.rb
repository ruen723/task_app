class User < ApplicationRecord
  has_secure_password reset_token: false
  has_many :sessions, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_one :schedule_setting, dependent: :destroy

  normalizes :username, with: ->(username) { username.strip }

  validates :username, presence: true, length: { in: 3..30 },
    format: { with: /\A[A-Za-z0-9_]+\z/ },
    uniqueness: { case_sensitive: true }
  validates :password, length: { minimum: 15 }, if: -> { new_record? || !password.nil? }
  validates :password_confirmation, length: { minimum: 1 }, on: :create
  validate :password_byte_length_for_whitespace

  private

  def password_byte_length_for_whitespace
    # has_secure_password skips the byte limit when the password consists only of whitespace.
    return unless password && password.blank? && password.bytesize > 72

    errors.add(:password, :password_too_long)
  end
end
