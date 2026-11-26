require "rails_helper"

RSpec.describe "タスクの登録と一覧" do
  let(:user) { FactoryBot.create(:user) }

  it "未認証では一覧・登録画面・登録処理にアクセスできない" do
    get tasks_path
    expect(response).to redirect_to(new_session_path)

    get new_task_path
    expect(response).to redirect_to(new_session_path)

    expect do
      post tasks_path, params: { task: { name: "朝食", planned_duration: "10" } }
    end.not_to change(Task, :count)
    expect(response).to redirect_to(new_session_path)
  end

  context "ログイン済みの場合" do
    before do
      post session_path, params: { username: user.username, password: user.password }
      expect(response).to redirect_to(root_path)
    end

    it "TOPから登録画面に進み、タスクが0件の場合は案内を表示する" do
      get root_path
      expect(response.body).to include(tasks_path)

      get tasks_path
      expect(response.body).to include("タスクはまだありません。", new_task_path)

      get new_task_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("タスク名", "予定所要時間")
    end

    it "境界値と同名タスクを受け付け、送信された所有者と順序を無視して末尾に追加する" do
      other_user = FactoryBot.create(:user)
      other_user.tasks.create!(name: "ほかのユーザーのタスク", planned_duration: 10, position: 1)

      [ 1, 1440 ].each do |duration|
        expect do
          post tasks_path, params: {
            task: { name: "朝食", planned_duration: duration.to_s, user_id: other_user.id, position: 30 }
          }
        end.to change { user.tasks.count }.by(1)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(tasks_path)
      end

      expect(user.tasks.order(:position).pluck(:name, :planned_duration, :position))
        .to eq([ [ "朝食", 1, 1 ], [ "朝食", 1440, 2 ] ])
      expect(other_user.tasks.count).to eq(1)
    end

    it "自分のタスクだけを実行順序で表示する" do
      user.tasks.create!(name: "着替え", planned_duration: 5, position: 2)
      user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
      FactoryBot.create(:user).tasks.create!(name: "他人のタスク", planned_duration: 5, position: 1)

      get tasks_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/朝食.*10分.*着替え.*5分/m)
      expect(response.body).not_to include("他人のタスク")
    end

    [ "", "0", "1441", "3.5", "3.0", "3abc", "abc" ].each do |duration|
      it "予定所要時間 #{duration.inspect} を拒否し、入力エラーを表示する" do
        expect do
          post tasks_path, params: { task: { name: "朝食", planned_duration: duration } }
        end.not_to change(Task, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("入力内容を確認してください。", "予定所要時間")
      end
    end

    it "タスク名が51文字の場合に登録せず、フォームを再表示する" do
      expect do
        post tasks_path, params: { task: { name: "朝" * 51, planned_duration: "10" } }
      end.not_to change(Task, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("入力内容を確認してください。")
    end

    it "タスク名が空の場合に登録しない" do
      expect do
        post tasks_path, params: { task: { name: "", planned_duration: "10" } }
      end.not_to change(Task, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context "データベース制約" do
    let(:task_attributes) { { user_id: user.id, name: "朝食", planned_duration: 10, position: 1 } }

    it "同じユーザーの同じ順序を拒否する" do
      Task.create!(task_attributes)

      expect { Task.insert_all!([ task_attributes ]) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "順序がNULLの行を拒否する" do
      expect do
        Task.insert_all!([ task_attributes.merge(position: nil) ])
      end.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "存在しないユーザーに紐づく行を拒否する" do
      expect do
        Task.insert_all!([ task_attributes.merge(user_id: User.maximum(:id) + 1) ])
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
