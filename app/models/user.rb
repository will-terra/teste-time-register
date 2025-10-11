# Model representing a user
class User < ApplicationRecord
  has_many :time_registers, dependent: :destroy
  has_many :reports, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Checks if the user has any open (not clocked out) time register
  def has_open_time_register?
    time_registers.where(clock_out: nil).exists?
  end
end
