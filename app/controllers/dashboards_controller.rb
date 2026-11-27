class DashboardsController < ApplicationController
  def show
    user = Current.user
    @tasks = user.tasks.order(:position).load
    @schedule_setting = user.schedule_setting
  end
end
