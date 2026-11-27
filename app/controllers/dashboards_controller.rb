class DashboardsController < ApplicationController
  def show
    user = Current.user
    @tasks = user.tasks.order(:position).load
    @schedule_setting = user.schedule_setting
    @total_planned_minutes = @tasks.sum(&:planned_duration)
    @time_breakdown = @schedule_setting&.time_breakdown(@total_planned_minutes)
  end
end
