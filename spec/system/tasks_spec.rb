require "rails_helper"

RSpec.describe "タスクの編集と削除" do
  let(:user) { FactoryBot.create(:user) }

  it "編集後に削除をキャンセルでき、確認に同意した場合だけ削除する" do
    user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
    visit new_session_path
    fill_in "ユーザー名", with: user.username
    fill_in "パスワード", with: user.password
    click_button "ログイン"
    click_link "タスク一覧"

    click_link "編集"
    fill_in "タスク名", with: "着替え"
    fill_in "予定所要時間", with: 15
    click_button "更新する"
    expect(page).to have_text("着替え（15分）")

    dismiss_confirm("このタスクを削除しますか？") { click_link "削除" }
    expect(page).to have_text("着替え（15分）")

    accept_confirm("このタスクを削除しますか？") { click_link "削除" }
    expect(page).to have_text("タスクはまだありません。")
  end

  it "JavaScriptを実行しないブラウザでは、削除リンクを開いても削除されない" do
    task = user.tasks.create!(name: "朝食", planned_duration: 10, position: 1)
    browser = page.driver.browser
    browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
    visit new_session_path
    fill_in "ユーザー名", with: user.username
    fill_in "パスワード", with: user.password
    click_button "ログイン"
    click_link "タスク一覧"

    expect { click_link "削除" }.not_to change(Task, :count)
    expect(page).to have_current_path(task_path(task))
    expect(task.reload.name).to eq("朝食")
  ensure
    browser&.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
  end

  it "登録・ログイン・ログアウトと入力エラー表示を通常の画面遷移で利用できる" do
    password = "morning-plan-123"
    visit new_user_path
    fill_in "ユーザー名", with: "morning_routine"
    fill_in "パスワード", exact: true, with: password
    fill_in "パスワード（確認）", with: "different-password"
    click_button "登録する"
    expect(page).to have_text("入力内容を確認してください。")

    fill_in "パスワード", exact: true, with: password
    fill_in "パスワード（確認）", with: password
    click_button "登録する"
    expect(page).to have_text("ログイン済み")
    click_button "ログアウト"
    click_link "ログイン"

    fill_in "ユーザー名", with: "morning_routine"
    fill_in "パスワード", with: "wrong-password"
    click_button "ログイン"
    expect(page).to have_text("ユーザー名またはパスワードが正しくありません。")

    fill_in "パスワード", with: password
    click_button "ログイン"
    click_link "タスク一覧"
    click_link "タスクを登録する"
    fill_in "タスク名", with: " "
    fill_in "予定所要時間", with: 10
    click_button "登録する"
    expect(page).to have_text("入力内容を確認してください。")

    fill_in "タスク名", with: "朝食"
    click_button "登録する"
    expect(page).to have_text("朝食（10分）")
  end
end
