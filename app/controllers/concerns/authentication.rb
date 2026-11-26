module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :authenticated?
  end

  private

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
end
