require "rails_helper"

RSpec.describe "タスクの登録と一覧" do
  let(:user) { FactoryBot.create(:user) }

  it "未認証では編集・更新・削除できない" do
    task = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)

    get edit_task_path(task)
    expect(response).to redirect_to(new_session_path)

    patch task_path(task), params: { task: { name: "着替え" } }
    expect(response).to redirect_to(new_session_path)
    expect(task.reload.name).to eq("朝食")

    expect { delete task_path(task) }.not_to change(Task, :count)
    expect(response).to redirect_to(new_session_path)
  end

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

  context "実行順序の変更" do
    let!(:first) { user.tasks.create!(name: "朝食", planned_duration: 10, position: 1) }
    let!(:middle) { user.tasks.create!(name: "着替え", planned_duration: 5, position: 2) }
    let!(:last) { user.tasks.create!(name: "歯磨き", planned_duration: 3, position: 3) }

    def task_order
      user.tasks.order(:position).pluck(:id, :position)
    end

    it "未認証では順序を変更できない" do
      expect do
        patch reorder_task_path(middle), params: { direction: "up" }
      end.not_to change { task_order }
      expect(response).to redirect_to(new_session_path)
    end

    context "ログイン済みの場合" do
      before do
        post session_path, params: { username: user.username, password: user.password }
      end

      it "上下に移動でき、順序は連番のままで別ユーザーのタスクに影響しない" do
        other_task = FactoryBot.create(:user).tasks.create!(name: "読書", planned_duration: 5, position: 1)

        patch reorder_task_path(middle), params: { direction: "up", position: 99, user_id: other_task.user_id }
        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(tasks_path)
        expect(task_order).to eq([ [ middle.id, 1 ], [ first.id, 2 ], [ last.id, 3 ] ])

        patch reorder_task_path(middle), params: { direction: "down" }
        expect(response).to have_http_status(:see_other)
        expect(task_order).to eq([ [ first.id, 1 ], [ middle.id, 2 ], [ last.id, 3 ] ])
        expect(other_task.reload).to have_attributes(name: "読書", planned_duration: 5, position: 1)
      end

      it "先頭と末尾の外へ移動せず、一覧に戻す" do
        [ [ first, "up" ], [ last, "down" ] ].each do |task, direction|
          expect do
            patch reorder_task_path(task), params: { direction: direction }
          end.not_to change { task_order }
          expect(response).to have_http_status(:see_other)
          expect(response).to redirect_to(tasks_path)
        end
      end

      it "唯一のタスクはどちらにも移動できない" do
        middle.destroy!
        last.destroy!

        %w[up down].each do |direction|
          expect do
            patch reorder_task_path(first), params: { direction: direction }
          end.not_to change { task_order }
          expect(response).to have_http_status(:see_other)
          expect(response).to redirect_to(tasks_path)
        end
      end

      it "方向の未指定・不正値・配列・ハッシュには400を返す" do
        [ {}, { direction: "left" }, { direction: [ "up" ] }, { direction: { value: "up" } } ].each do |parameters|
          expect do
            patch reorder_task_path(middle), params: parameters
          end.not_to change { task_order }
          expect(response).to have_http_status(:bad_request)
        end
      end

      it "他ユーザーまたは存在しないタスクには404を返す" do
        other_task = FactoryBot.create(:user).tasks.create!(name: "読書", planned_duration: 5, position: 1)

        [ other_task.id, 0 ].each do |id|
          expect do
            patch reorder_task_path(id), params: { direction: "down" }
          end.not_to change { task_order }
          expect(response).to have_http_status(:not_found)
        end

        expect(other_task.reload.position).to eq(1)
      end

      it "移動先に欠番がある場合は変更せず案内を表示する" do
        middle.destroy!

        expect do
          patch reorder_task_path(first), params: { direction: "down" }
        end.not_to change { task_order }
        expect(response).to redirect_to(tasks_path)
        follow_redirect!
        expect(response.body).to include("タスクの順序を変更できませんでした。")
      end

      it "隣接タスクの保存に失敗した場合は退避した順位を元に戻す" do
        first.update_column(:name, "")

        expect do
          patch reorder_task_path(middle), params: { direction: "up" }
        end.not_to change { task_order }
        expect(response).to redirect_to(tasks_path)
        follow_redirect!
        expect(response.body).to include("タスクの順序を変更できませんでした。")
      end
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

  context "ログイン後の編集・削除" do
    before do
      post session_path, params: { username: user.username, password: user.password }
    end

    it "他ユーザーのタスクには編集・更新・削除のいずれでも404を返す" do
      other_user = FactoryBot.create(:user)
      task = other_user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)

      get edit_task_path(task)
      expect(response).to have_http_status(:not_found)

      patch task_path(task), params: { task: { name: "着替え" } }
      expect(response).to have_http_status(:not_found)

      expect { delete task_path(task) }.not_to change(Task, :count)
      expect(response).to have_http_status(:not_found)
      expect(task.reload.name).to eq("朝食")
    end

    it "存在しないタスクには編集・更新・削除のいずれでも404を返す" do
      missing_id = 0

      get edit_task_path(missing_id)
      expect(response).to have_http_status(:not_found)

      patch task_path(missing_id), params: { task: { name: "着替え" } }
      expect(response).to have_http_status(:not_found)

      delete task_path(missing_id)
      expect(response).to have_http_status(:not_found)
    end

    it "現在の内容を編集画面に表示し、所有者と順序を維持して内容を更新する" do
      task = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
      other_user = FactoryBot.create(:user)

      get edit_task_path(task)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("タスク編集", "朝食")

      patch task_path(task), params: {
        task: { name: "着替え", planned_duration: "20", user_id: other_user.id, position: 5 }
      }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(tasks_path)
      expect(task.reload).to have_attributes(name: "着替え", planned_duration: 20, user_id: user.id, position: 1)
    end

    it "入力が不正なら保存せず、日本語のエラーと編集フォームを表示する" do
      task = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)

      patch task_path(task), params: { task: { name: "", planned_duration: "3.5" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("タスク編集", "入力内容を確認してください。", "整数")
      expect(task.reload).to have_attributes(name: "朝食", planned_duration: 10)
    end

    { "先頭" => [ 3, 1 ], "途中" => [ 3, 2 ], "末尾" => [ 3, 3 ], "唯一" => [ 1, 1 ] }.each do |label, (count, removed_position)|
      it "#{label}のタスクを削除し、残ったタスクの順番と別ユーザーのデータを維持する" do
        tasks = (1..count).map do |position|
          user.tasks.create!(name: "タスク#{position}", planned_duration: 10, position: position)
        end
        removed_task = tasks.fetch(removed_position - 1)
        other_user = FactoryBot.create(:user)
        other_task = other_user.tasks.create!(name: "別のタスク", planned_duration: 5, position: 1)

        expect { delete task_path(removed_task) }.to change(Task, :count).by(-1)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(tasks_path)
        expect(user.tasks.order(:position).pluck(:id, :position))
          .to eq((tasks - [ removed_task ]).map.with_index(1) { |task, position| [ task.id, position ] })
        expect(other_task.reload).to have_attributes(position: 1, name: "別のタスク")
      end
    end

    it "順序調整の途中で保存に失敗すると、削除と先に行った繰り上げを取り消す" do
      first = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
      second = user.tasks.create!(name: "着替え", planned_duration: 5, position: 2)
      third = user.tasks.create!(name: "歯磨き", planned_duration: 3, position: 3)
      # 3件目だけ保存に失敗するよう、バリデーションを経由せずテストデータを作る。
      third.update_column(:name, "")

      expect { delete task_path(first) }.not_to change(Task, :count)

      expect(response).to redirect_to(tasks_path)
      expect(user.tasks.order(:position).pluck(:id, :position)).to eq([ [ first.id, 1 ], [ second.id, 2 ], [ third.id, 3 ] ])
      follow_redirect!
      expect(response.body).to include("タスクを削除できませんでした。")
    end
  end
end
