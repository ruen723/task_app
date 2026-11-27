class ScheduleSettingsController < ApplicationController
  def edit
    user = Current.user
    @schedule_setting = user.schedule_setting || user.build_schedule_setting
  end

  def create
    save_setting
  end

  def update
    save_setting
  end

  private

  def save_setting
    user = Current.user
    saved = user.with_lock do
      @schedule_setting = user.schedule_setting || user.build_schedule_setting
      @schedule_setting.update(schedule_setting_params)
    end

    if saved
      redirect_to dashboard_path, status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to edit_schedule_setting_path, status: :see_other,
      alert: t("schedule_settings.errors.conflict")
  end

  def schedule_setting_params
    params.expect(schedule_setting: %i[start_time end_time])
  end
end
