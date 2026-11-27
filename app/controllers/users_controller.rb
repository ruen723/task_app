class UsersController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    session = User.transaction do
      create_session_for(@user) if save_user
    end

    if session
      set_current_session(session)
      redirect_to dashboard_path, status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def save_user
    @user.save
  rescue ActiveRecord::RecordNotUnique
    @user.errors.add(:base, :registration_failed)
    false
  end

  def user_params
    params.expect(user: %i[username password password_confirmation])
  end
end
