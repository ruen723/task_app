require "rails_helper"

RSpec.describe "ダッシュボード" do
  let(:user) { FactoryBot.create(:user) }

  it "未認証の場合はログイン画面へ案内する" do
    get dashboard_path

    expect(response).to redirect_to(new_session_path)
  end

  context "ログイン済みの場合" do
    before do
      post session_path, params: { username: user.username, password: user.password }
    end

    it "公開TOPからダッシュボードへ進める" do
      get root_path

      expect(response.body).to include(dashboard_path)
    end

    it "時間枠が未設定でもタスクを登録でき、設定への案内を表示する" do
      other_user = FactoryBot.create(:user)
      other_user.create_schedule_setting!(start_time: "07:00", end_time: "08:00")

      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ダッシュボード", "タスクはまだありません。", new_task_path)
      expect(response.body).to include("時間枠が未設定です", edit_schedule_setting_path)
      expect(response.body).not_to include("時間枠を変更する")

      expect do
        post tasks_path, params: { task: { name: "朝食", planned_duration: "10" } }
      end.to change { user.tasks.count }.by(1)
      expect(response).to redirect_to(dashboard_path)
    end

    it "本人のタスクだけを実行順序で表示し、編集と時間枠変更へ案内する" do
      second = user.tasks.create!(name: "着替え", planned_duration: 5, position: 2)
      first = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
      FactoryBot.create(:user).tasks.create!(name: "他人のタスク", planned_duration: 5, position: 1)
      user.create_schedule_setting!(start_time: "07:00", end_time: "08:00")

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/朝食.*10分.*着替え.*5分/m)
      expect(response.body).not_to include("他人のタスク", "時間枠が未設定です")
      expect(response.body).to include(edit_task_path(first), edit_task_path(second))
      expect(response.body).to include("時間枠を変更する", edit_schedule_setting_path)
    end
  end
end
