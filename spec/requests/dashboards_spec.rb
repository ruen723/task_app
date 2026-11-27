require "rails_helper"

RSpec.describe "ダッシュボード" do
  let(:user) { FactoryBot.create(:user) }

  def displayed_minutes
    Nokogiri::HTML(response.body).css("dl > dt").to_h do |label|
      [ label.text.strip, label.next_element.text.strip ]
    end
  end

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
      expect(displayed_minutes).to eq("予定合計時間" => "0分")

      expect do
        post tasks_path, params: { task: { name: "朝食", planned_duration: "10" } }
      end.to change { user.tasks.count }.by(1)
      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(displayed_minutes).to eq("予定合計時間" => "10分")
    end

    it "本人のタスクだけを実行順序で表示し、編集と時間枠変更へ案内する" do
      second = user.tasks.create!(name: "着替え", planned_duration: 5, position: 2)
      first = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
      other_user = FactoryBot.create(:user)
      other_user.tasks.create!(name: "他人のタスク", planned_duration: 90, position: 1)
      other_user.create_schedule_setting!(start_time: "06:00", end_time: "09:00")
      user.create_schedule_setting!(start_time: "07:00", end_time: "08:00")

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/朝食.*10分.*着替え.*5分/m)
      expect(response.body).not_to include("他人のタスク", "時間枠が未設定です")
      expect(response.body).to include(edit_task_path(first), edit_task_path(second))
      expect(response.body).to include("時間枠を変更する", edit_schedule_setting_path)
      expect(displayed_minutes).to eq(
        "予定合計時間" => "15分", "利用可能時間" => "60分", "自由時間" => "45分", "超過時間" => "0分"
      )
    end

    it "時間枠とタスクの保存後に最新の時間を表示する" do
      post schedule_setting_path, params: { schedule_setting: { start_time: "07:00", end_time: "08:00" } }
      follow_redirect!
      expect(displayed_minutes).to eq(
        "予定合計時間" => "0分", "利用可能時間" => "60分", "自由時間" => "60分", "超過時間" => "0分"
      )

      post tasks_path, params: { task: { name: "朝食", planned_duration: "45" } }
      follow_redirect!
      expect(displayed_minutes).to include("予定合計時間" => "45分", "自由時間" => "15分")

      task = user.tasks.sole
      patch task_path(task), params: { task: { planned_duration: "61" } }
      follow_redirect!
      expect(displayed_minutes).to include("予定合計時間" => "61分", "自由時間" => "0分", "超過時間" => "1分")

      patch schedule_setting_path, params: { schedule_setting: { start_time: "07:00", end_time: "08:01" } }
      follow_redirect!
      expect(displayed_minutes).to include("利用可能時間" => "61分", "自由時間" => "0分", "超過時間" => "0分")

      delete task_path(task)
      follow_redirect!
      expect(displayed_minutes).to include("予定合計時間" => "0分", "自由時間" => "61分", "超過時間" => "0分")
    end
  end
end
