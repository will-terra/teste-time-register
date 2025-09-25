class Report < ApplicationRecord
  belongs_to :user

  STATUSES = %w[queued processing completed failed].freeze

  validates :process_id, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :start_date, :end_date, presence: true
  validates :progress, presence: true, numericality: { in: 0..100 }

  validate :end_date_after_start_date

  before_validation :set_defaults, on: :create

  scope :by_status, ->(status) { where(status: status) }

  def queued?
    status == 'queued'
  end

  def processing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  def file_exists?
    file_path.present? && File.exist?(file_path)
  end

  private

  def set_defaults
    self.process_id ||= SecureRandom.uuid
    self.status ||= 'queued'
    self.progress ||= 0
  end

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end