class ScheduleSetting < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true
  validates :start_time, :end_time, presence: true
  validate :minute_precision
  validate :end_time_after_start_time

  def available_minutes
    (end_time.hour * 60 + end_time.min) - (start_time.hour * 60 + start_time.min)
  end

  def time_breakdown(total_planned_minutes)
    available = available_minutes
    remaining = available - total_planned_minutes

    {
      available_minutes: available,
      free_minutes: [ remaining, 0 ].max,
      overflow_minutes: [ -remaining, 0 ].max
    }
  end

  private

  def minute_precision
    %w[start_time end_time].each do |attribute|
      input = read_attribute_before_type_cast(attribute)
      time = public_send(attribute)

      if attribute_came_from_user?(attribute) && input.is_a?(String) && input.present? &&
          !input.match?(/\A(?:[01][0-9]|2[0-3]):[0-5][0-9]\z/)
        errors.add(attribute, :invalid_clock_time)
      elsif time && (time.sec != 0 || time.nsec != 0)
        errors.add(attribute, :invalid_clock_time)
      end
    end
  end

  def end_time_after_start_time
    return if errors[:start_time].any? || errors[:end_time].any?
    return if end_time.strftime("%H:%M") > start_time.strftime("%H:%M")

    errors.add(:end_time, :after_start_time)
  end
end
