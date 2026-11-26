require "rails_helper"

RSpec.describe "ログインとログアウト" do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "  morning-plan-123  " }
  let(:user) { FactoryBot.create(:user, username: "Morning_01", password: password) }
  let(:credentials) { { username: user.username, password: password } }

  it "未認証でもTOP、登録、ログイン、ヘルスチェックにアクセスできる" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(new_session_path)

    [ new_user_path, new_session_path, rails_health_check_path ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
    end
  end

  it "ユーザー名の前後の空白を除去し、新しいセッションで認証状態を復元する" do
    login_params = credentials.merge(username: "  #{user.username}  ")

    expect { post session_path, params: login_params }.to change(Session, :count).by(1)
    expect(Session.last.user).to eq(user)
    expect(response.cookies["session_id"]).to be_present
    expect(response).to redirect_to(root_path)

    follow_redirect!
    expect(response.body).to include("ログイン済み", "ログアウト")
  end

  {
    "存在しないユーザー名" => { username: "Unknown_01" },
    "大文字と小文字が異なるユーザー名" => { username: "morning_01" },
    "前後の空白を除去したパスワード" => { password: "morning-plan-123" },
    "誤ったパスワード" => { password: "wrong-password" }
  }.each do |description, overrides|
    it "#{description}を同じメッセージで拒否し、パスワードを再表示しない" do
      login_params = credentials.merge(overrides)

      expect { post session_path, params: login_params }.not_to change(Session, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("ユーザー名またはパスワードが正しくありません。")
      expect(Nokogiri::HTML(response.body).at_css("#password")["value"].to_s).to eq("")
      expect(cookies["session_id"]).to be_nil
    end
  end

  it "有効な72バイトのパスワードに1バイト足した入力を認証前に拒否する" do
    password_at_limit = "a" * 72
    account = FactoryBot.create(:user, password: password_at_limit)
    expect(User).not_to receive(:authenticate_by)

    expect do
      post session_path, params: { username: account.username, password: password_at_limit + "a" }
    end.not_to change(Session, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ユーザー名またはパスワードが正しくありません。")
  end

  it "認証済みのログイン要求では同じセッションを維持してTOPへ戻す" do
    post session_path, params: credentials
    original_cookie = cookies["session_id"]

    get new_session_path
    expect(response).to redirect_to(root_path)

    expect { post session_path, params: credentials }.not_to change(Session, :count)
    expect(response).to redirect_to(root_path)
    expect(cookies["session_id"]).to eq(original_cookie)
  end

  it "ログアウトで現在のセッションだけを削除し、旧Cookieの再利用を拒否する" do
    other_session = user.sessions.create!
    post session_path, params: credentials
    current_session = user.sessions.where.not(id: other_session.id).sole
    old_cookie = cookies["session_id"]

    delete session_path

    expect(response).to redirect_to(root_path)
    expect(Session.exists?(current_session.id)).to be(false)
    expect(Session.exists?(other_session.id)).to be(true)
    expect(cookies["session_id"]).to be_blank

    cookies["session_id"] = old_cookie
    follow_redirect!
    expect(response.body).not_to include("ログイン済み")
  end

  it "未認証のログアウト要求をログイン画面へ案内する" do
    delete session_path

    expect(response).to redirect_to(new_session_path)
  end

  it "3分間の11回目の試行を送信元IPごとに制限する" do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails.cache).to receive(:increment) do |key, amount, **options|
      cache.increment(key, amount, **options)
    end

    travel_to Time.current do
      invalid_credentials = credentials.merge(password: "wrong-password")
      10.times do
        post session_path, params: invalid_credentials
        expect(response).to have_http_status(:unprocessable_content)
      end

      expect { post session_path, params: credentials }.not_to change(Session, :count)
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("時間をおいてからもう一度お試しください")

      post session_path, params: invalid_credentials, env: { "REMOTE_ADDR" => "192.0.2.10" }
      expect(response).to have_http_status(:unprocessable_content)

      travel 3.minutes + 1.second
      post session_path, params: credentials
      expect(response).to redirect_to(root_path)
    end
  end
end
