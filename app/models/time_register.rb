class TimeRegister < ApplicationRecord
  belongs_to :user

  validates :clock_in, presence: true
  validate :user_cannot_have_multiple_open_registers
  validate :clock_out_must_be_after_clock_in

  private

  def user_cannot_have_multiple_open_registers
    return unless user && clock_out.nil?
    
    existing_open_registers = user.time_registers.where(clock_out: nil)
    existing_open_registers = existing_open_registers.where.not(id: id) if persisted?
    
    if existing_open_registers.exists?
      errors.add(:base, "User already has an open time register")
    end
  end

  def clock_out_must_be_after_clock_in
    return unless clock_in && clock_out
    
    if clock_out <= clock_in
      errors.add(:clock_out, "must be after clock in time")
    end
  end
end
