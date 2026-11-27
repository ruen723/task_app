require "rails_helper"

RSpec.describe "時間枠設定" do
  let(:user) { FactoryBot.create(:user) }
  let(:times) { { start_time: "07:05", end_time: "08:10" } }

  it "未認証ではフォームを表示せず、作成・更新もできない" do
    get edit_schedule_setting_path
    expect(response).to redirect_to(new_session_path)

    expect do
      post schedule_setting_path, params: { schedule_setting: times }
      expect(response).to redirect_to(new_session_path)
      patch schedule_setting_path, params: { schedule_setting: times }
      expect(response).to redirect_to(new_session_path)
    end.not_to change(ScheduleSetting, :count)
  end

  context "ログイン済みの場合" do
    before do
      post session_path, params: { username: user.username, password: user.password }
    end

    it "初回は登録し、再送信や更新では同じ設定を上書きする" do
      get edit_schedule_setting_path
      expect(response).to have_http_status(:ok)

      expect do
        post schedule_setting_path, params: { schedule_setting: times }
      end.to change(ScheduleSetting, :count).by(1)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(dashboard_path)
      setting = user.reload.schedule_setting

      get edit_schedule_setting_path
      expect(response.body).to include('value="07:05"', 'value="08:10"')

      expect do
        post schedule_setting_path, params: { schedule_setting: times }
        expect(response).to have_http_status(:see_other)
        patch schedule_setting_path, params: { schedule_setting: { start_time: "06:30", end_time: "08:45" } }
        expect(response).to have_http_status(:see_other)
      end.not_to change(ScheduleSetting, :count)
      expect(user.reload.schedule_setting.id).to eq(setting.id)
      expect(setting.reload.start_time.strftime("%H:%M")).to eq("06:30")
      expect(setting.end_time.strftime("%H:%M")).to eq("08:45")
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "他ユーザーの時刻を表示せず、送信されたIDで他ユーザーの設定を更新しない" do
      other_user = FactoryBot.create(:user)
      other_setting = other_user.create_schedule_setting!(start_time: "11:11", end_time: "12:12")

      get edit_schedule_setting_path, params: { user_id: other_user.id, id: other_setting.id }
      expect(response.body).not_to include('value="11:11"', 'value="12:12"')

      patch schedule_setting_path, params: {
        schedule_setting: times.merge(user_id: other_user.id, id: other_setting.id)
      }
      expect(response).to redirect_to(dashboard_path)
      expect(user.reload.schedule_setting.start_time.strftime("%H:%M")).to eq("07:05")
      expect(other_setting.reload.start_time.strftime("%H:%M")).to eq("11:11")
      expect(other_setting.user_id).to eq(other_user.id)
    end

    it "不正な更新では日本語のエラーを表示し、保存済みの時刻を維持する" do
      setting = user.create_schedule_setting!(times)

      patch schedule_setting_path, params: {
        schedule_setting: { start_time: "09:00", end_time: "08:10" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("終了時刻", "開始時刻より後に設定してください")
      expect(setting.reload.start_time.strftime("%H:%M")).to eq("07:05")
      expect(setting.end_time.strftime("%H:%M")).to eq("08:10")
    end
  end
end
