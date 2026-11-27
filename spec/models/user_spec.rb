require "rails_helper"

RSpec.describe User do
  it "ファクトリで生成したユーザーは有効である" do
    expect(FactoryBot.build(:user)).to be_valid
  end

  describe "ユーザー名" do
    it "未入力の場合は無効である" do
      user = FactoryBot.build(:user, username: nil)

      expect(user).not_to be_valid
      expect(user.errors.of_kind?(:username, :blank)).to be(true)
    end

    [ 3, 30 ].each do |length|
      it "#{length}文字を許可する" do
        expect(FactoryBot.build(:user, username: "a" * length)).to be_valid
      end
    end

    { 2 => :too_short, 31 => :too_long }.each do |length, error|
      it "#{length}文字を拒否する" do
        user = FactoryBot.build(:user, username: "a" * length)

        expect(user).not_to be_valid
        expect(user.errors.of_kind?(:username, error)).to be(true)
      end
    end

    [ "Ｕser_01", "User 01" ].each do |username|
      it "「#{username}」を拒否する" do
        user = FactoryBot.build(:user, username: username)

        expect(user).not_to be_valid
        expect(user.errors.of_kind?(:username, :invalid)).to be(true)
      end
    end

    it "前後の空白を除去し、半角英数字とアンダースコアの表記を保持する" do
      user = FactoryBot.create(:user, username: "  Morning_01  ")

      expect(user.reload.username).to eq("Morning_01")
    end

    it "登録済みの名前と同じ表記は拒否する" do
      FactoryBot.create(:user, username: "Morning_01")
      user = FactoryBot.build(:user, username: "  Morning_01  ")

      expect(user).not_to be_valid
      expect(user.errors.of_kind?(:username, :taken)).to be(true)
    end

    it "大文字と小文字だけが異なる名前を保存できる" do
      FactoryBot.create(:user, username: "Morning_01")
      user = FactoryBot.create(:user, username: "morning_01")

      expect(user.reload.username).to eq("morning_01")
    end
  end

  describe "パスワード" do
    it "未入力の場合は無効である" do
      user = FactoryBot.build(:user, password: nil, password_confirmation: nil)

      expect(user).not_to be_valid
      expect(user.errors.of_kind?(:password, :blank)).to be(true)
    end

    it "14文字を拒否する" do
      user = FactoryBot.build(:user, password: "a" * 14)

      expect(user).not_to be_valid
      expect(user.errors.of_kind?(:password, :too_short)).to be(true)
    end

    it "15文字を許可する" do
      expect(FactoryBot.build(:user, password: "a" * 15)).to be_valid
    end

    { "マルチバイト文字を含む入力" => "あ" * 24, "空白だけの入力" => " " * 72 }.each do |description, password|
      it "#{description}が72バイトなら許可する" do
        expect(FactoryBot.build(:user, password: password)).to be_valid
      end

      it "#{description}が73バイトなら拒否する" do
        user = FactoryBot.build(:user, password: password + " ")

        expect(user).not_to be_valid
        expect(user.errors.of_kind?(:password, :password_too_long)).to be(true)
      end
    end

    it "確認入力が未入力の場合は無効である" do
      user = FactoryBot.build(:user, password_confirmation: nil)

      expect(user).not_to be_valid
      expect(user.errors.of_kind?(:password_confirmation, :too_short)).to be(true)
    end

    it "確認入力がパスワードと異なる場合は無効である" do
      user = FactoryBot.build(:user, password_confirmation: "wrong-password")

      expect(user).not_to be_valid
      expect(user.errors.of_kind?(:password_confirmation, :confirmation)).to be(true)
    end

    it "前後の空白を含むパスワードをハッシュ化して保存し、正しい入力でのみ認証する" do
      password = "  morning-plan-123  "
      user = FactoryBot.create(:user, password: password)
      saved_user = User.find(user.id)

      expect(saved_user.password_digest).to be_present
      expect(saved_user.password_digest).not_to eq(password)
      expect(saved_user.authenticate(password)).to eq(saved_user)
      expect(saved_user.authenticate(password.strip)).to be(false)
      expect(saved_user.authenticate("wrong-password")).to be(false)
    end
  end

  describe "セッション" do
    it "保存したセッションをユーザーに紐づける" do
      user = FactoryBot.create(:user)
      session = user.sessions.create!

      expect(user.reload.sessions).to contain_exactly(session)
      expect(session.reload.user).to eq(user)
    end

    it "ユーザーを削除するとそのユーザーのセッションも削除する" do
      user = FactoryBot.create(:user)
      session = user.sessions.create!
      other_session = FactoryBot.create(:user).sessions.create!

      user.destroy!

      expect(Session.exists?(session.id)).to be(false)
      expect(Session.exists?(other_session.id)).to be(true)
    end
  end
end
