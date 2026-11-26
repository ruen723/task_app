class Task < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { maximum: 50 }
  validates :planned_duration, presence: true, numericality: { only_integer: true, in: 1..1440 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
