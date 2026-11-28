require "rails_helper"

RSpec.describe "ダッシュボードの時間の見える化" do
  def timeline_bounds
    expect(page).to have_css(".timeline-frame")

    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll(".timeline-frame, .timeline-block"), (element) => {
        const { top, bottom, height } = element.getBoundingClientRect()
        return { top, bottom, height }
      })
    JS
  end

  it "枠とタスクを同じ尺度・起点で描画し、時間枠を短くしてもタスクの高さを維持する" do
    user = FactoryBot.create(:user)
    setting = user.create_schedule_setting!(start_time: "07:00", end_time: "07:20")
    user.tasks.create!(name: "歯磨き", planned_duration: 1, position: 1)
    user.tasks.create!(name: "朝食", planned_duration: 19, position: 2)

    visit new_session_path
    fill_in "ユーザー名", with: user.username
    fill_in "パスワード", with: user.password
    click_button "ログイン"
    expect(page).to have_current_path(dashboard_path)

    frame, first, second = timeline_bounds
    expect([ frame["height"], first["height"], second["height"] ]).to eq([ 60, 3, 57 ])
    expect(first["top"]).to eq(frame["top"])
    expect(second["top"]).to eq(first["bottom"])
    expect(second["bottom"]).to eq(frame["bottom"])

    setting.update!(end_time: "07:10")
    visit dashboard_path

    frame, first, second = timeline_bounds
    expect([ frame["height"], first["height"], second["height"] ]).to eq([ 30, 3, 57 ])
    expect(first["top"]).to eq(frame["top"])
    expect(second["top"]).to eq(first["bottom"])
    expect(second["bottom"] - frame["bottom"]).to eq(30)
  end
end
