require "rails_helper"

RSpec.describe "ユーザー登録" do
  let(:password) { "a" * 15 }
  let(:attributes) do
    { username: "  Morning_User  ", password: password, password_confirmation: password }
  end

  it "TOPページから登録フォームを表示できる" do
    get root_path
    expect(response.body).to include(new_user_path)

    get new_user_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('autocomplete="new-password"')
  end

  it "パスワードをハッシュ化し、登録後のリクエストで認証状態を復元する" do
    expect { post users_path, params: { user: attributes } }
      .to change(User, :count).by(1).and change(Session, :count).by(1)

    user = User.find_by!(username: "Morning_User")
    expect(user.password_digest).not_to eq(password)
    expect(user.authenticate(password)).to eq(user)
    expect(user.sessions.count).to eq(1)
    expect(response.cookies["session_id"]).to be_present
    expect(response).to redirect_to(dashboard_path)

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ダッシュボード")

    cookies["session_id"] = "#{cookies["session_id"]}tampered"
    get dashboard_path
    expect(response).to redirect_to(new_session_path)
  end

  it "同じユーザー名を拒否し、大文字小文字が異なる名前を許可する" do
    post users_path, params: { user: attributes }
    expect(response).to redirect_to(dashboard_path)

    expect { post users_path, params: { user: attributes } }
      .not_to change(User, :count)
    expect(response).to have_http_status(422)
    expect(response.body).to include("ユーザー名を使用できません")

    expect { post users_path, params: { user: attributes.merge(username: "morning_user") } }
      .to change(User, :count).by(1)
    expect(response).to redirect_to(dashboard_path)
  end

  it "DBが重複を拒否した場合、ユーザーとセッションを増やさず一般的なエラーを表示する" do
    User.create!(attributes)
    duplicate_user = User.new(attributes)
    allow(User).to receive(:new).and_return(duplicate_user)
    # 競合時と同様に、モデルの検証で止めず実際のDBに保存を試みる。
    allow(duplicate_user).to receive(:save) do
      duplicate_user.save!(validate: false)
    end

    expect { post users_path, params: { user: attributes } }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(422)
    expect(response.body).to include("登録できませんでした。入力内容を確認してください。")
  end

  it "セッション保存に失敗した場合は登録を取り消し、認証Cookieを発行しない" do
    allow_any_instance_of(UsersController).to receive(:create_session_for)
      .and_raise(ActiveRecord::RecordNotUnique, "session write failed")

    expect { post users_path, params: { user: attributes } }
      .to raise_error(ActiveRecord::RecordNotUnique, "session write failed")
    expect(User.find_by(username: "Morning_User")).to be_nil
    expect(Session.count).to eq(0)
    expect(cookies["session_id"]).to be_nil
  end

  it "短時間に同じ送信元から登録が繰り返された場合はHTTP 429を返す" do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails.cache).to receive(:increment) do |key, amount, **options|
      cache.increment(key, amount, **options)
    end
    invalid_attributes = attributes.merge(username: "!")

    10.times do
      post users_path, params: { user: invalid_attributes }
      expect(response).to have_http_status(422)
    end

    expect { post users_path, params: { user: attributes } }
      .to change(User, :count).by(0).and change(Session, :count).by(0)
    expect(response).to have_http_status(:too_many_requests)
  end

  {
    "文字と空白が混じる" => " " + ("あ" * 23) + "  ",
    "空白だけの" => " " * 72
  }.each do |description, password_at_limit|
    it "#{description}72バイトのパスワードを正規化せず登録できる" do
      post users_path, params: {
        user: attributes.merge(password: password_at_limit, password_confirmation: password_at_limit)
      }

      expect(response).to redirect_to(dashboard_path)
      user = User.find_by!(username: "Morning_User")
      expect(user.authenticate(password_at_limit)).to eq(user)
      expect(user.authenticate(password_at_limit.strip)).to be(false)
    end
  end

  {
    "ユーザー名に許可されない文字がある" => [
      { username: "朝の支度" }, "ユーザー名は不正な値です"
    ],
    "パスワードが14文字である" => [
      { password: "a" * 14, password_confirmation: "a" * 14 }, "パスワードは15文字以上で入力してください"
    ],
    "パスワードが73バイトである" => [
      { password: ("あ" * 24) + "a", password_confirmation: ("あ" * 24) + "a" }, "パスワードは72バイト以内で入力してください"
    ],
    "空白だけのパスワードが73バイトである" => [
      { password: " " * 73, password_confirmation: " " * 73 }, "パスワードは72バイト以内で入力してください"
    ],
    "確認入力が一致しない" => [
      { password_confirmation: "wrong" }, "パスワード（確認）とパスワードの入力が一致しません"
    ],
    "確認入力がない" => [
      { password_confirmation: nil }, "パスワード（確認）は1文字以上で入力してください"
    ]
  }.each do |description, (overrides, message)|
    it "#{description}場合、登録せずにフォームを再表示する" do
      submitted = attributes.merge(overrides)
      expect { post users_path, params: { user: submitted } }
        .to change(User, :count).by(0).and change(Session, :count).by(0)

      expect(response).to have_http_status(422)
      expect(response.body).to include("入力内容を確認してください")
      expect(response.body).to include(message)
      form = Nokogiri::HTML(response.body)
      expect(form.at_css("#user_password")["value"].to_s).to eq("")
      expect(form.at_css("#user_password_confirmation")["value"].to_s).to eq("")
    end
  end
end
