class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  before_action :redirect_if_authenticated, only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    render_login_error(:rate_limited, :too_many_requests)
  }

  def new
  end

  def create
    credentials = params.permit(:username, :password)
    username = credentials[:username]
    password = credentials[:password]
    @username = username if username.is_a?(String)

    if @username && password.is_a?(String) && password.bytesize <= 72 &&
        (user = User.authenticate_by(username: @username, password: password))
      set_current_session(create_session_for(user))
      redirect_to dashboard_path, status: :see_other
    else
      render_login_error(:invalid_credentials, :unprocessable_content)
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def redirect_if_authenticated
    redirect_to dashboard_path, status: :see_other if authenticated?
  end

  def render_login_error(message, status)
    flash.now[:alert] = t("sessions.errors.#{message}")
    render :new, status: status
  end
end
