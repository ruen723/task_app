module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    return if authenticated?

    redirect_to new_session_path, status: :see_other
  end

  def authenticated?
    resume_session.present?
  end

  def resume_session
    Current.session ||= find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  def create_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
  end

  def set_current_session(session)
    reset_session
    Current.session = session
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
  end

  def terminate_session
    Current.session.destroy!
    Current.session = nil
    reset_session
    cookies.delete(:session_id)
  end
end
