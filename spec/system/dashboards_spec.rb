require "rails_helper"

RSpec.describe "ダッシュボードの時間の見える化" do
  def timeline_bounds(selector = ".timeline-frame, .timeline-block")
    expect(page).to have_css(".timeline-frame")

    page.evaluate_script(<<~JS, selector)
      Array.from(document.querySelectorAll(arguments[0]), (element) => {
        const { top, bottom, height } = element.getBoundingClientRect()
        return { top, bottom, height }
      })
    JS
  end

  def log_in(user)
    visit new_session_path
    fill_in "ユーザー名", with: user.username
    fill_in "パスワード", with: user.password
    click_button "ログイン"
    expect(page).to have_current_path(dashboard_path)
  end

  it "枠とタスクを同じ尺度・起点で描画し、時間枠を短くしてもタスクの高さを維持する" do
    user = FactoryBot.create(:user)
    setting = user.create_schedule_setting!(start_time: "07:00", end_time: "07:20")
    user.tasks.create!(name: "歯磨き", planned_duration: 1, position: 1)
    user.tasks.create!(name: "朝食", planned_duration: 19, position: 2)

    log_in(user)

    frame, first, second = timeline_bounds
    expect([ frame["height"], first["height"], second["height"] ]).to eq([ 60, 3, 57 ])
    expect(first["top"]).to eq(frame["top"])
    expect(second["top"]).to eq(first["bottom"])
    expect(second["bottom"]).to eq(frame["bottom"])

    expect(page).to have_no_css(".timeline-free", visible: :all)
    expect(page).to have_css(".timeline-block .timeline-label", text: "朝食（19分）", visible: :visible)
    expect(page).to have_css(".timeline-block .timeline-label", text: "歯磨き（1分）", visible: :hidden)

    setting.update!(end_time: "08:00")
    visit dashboard_path
    expect(page).to have_css(".timeline-free .timeline-label", text: "自由時間（40分）", visible: :visible)
    free, = timeline_bounds(".timeline-free")
    expect(free["height"]).to eq(120)

    setting.update!(end_time: "07:21")
    visit dashboard_path
    frame, first, second = timeline_bounds
    free, = timeline_bounds(".timeline-free")
    expect(free["height"]).to eq(3)
    expect(page).to have_css(".timeline-free .timeline-label", text: "自由時間（1分）", visible: :hidden)
    expect(free["top"]).to eq(second["bottom"])
    expect(free["bottom"]).to eq(frame["bottom"])

    setting.update!(end_time: "07:19")
    visit dashboard_path

    frame, first, second = timeline_bounds
    expect([ frame["height"], first["height"], second["height"] ]).to eq([ 57, 3, 57 ])
    expect(first["top"]).to eq(frame["top"])
    expect(second["top"]).to eq(first["bottom"])
    overflow, = timeline_bounds(".timeline-overflow")
    expect(overflow["height"]).to eq(3)
    expect(overflow["top"]).to eq(frame["bottom"])
    expect(overflow["bottom"]).to eq(second["bottom"])

    user.tasks.create!(name: "工作", planned_duration: 1440, position: 3)
    visit dashboard_path
    frame, _, second, third = timeline_bounds
    overflow, = timeline_bounds(".timeline-overflow")
    expect(third["height"]).to eq(4320)
    expect(third["top"]).to eq(second["bottom"])
    expect(overflow["height"]).to eq(4323)
    expect(overflow["top"]).to eq(frame["bottom"])
    expect(overflow["bottom"]).to eq(third["bottom"])
    expect(page.evaluate_script(<<~JS)).to eq(true)
      (() => {
        const scroll = document.querySelector(".timeline-scroll")
        scroll.scrollTop = scroll.scrollHeight
        return document.querySelector(".timeline-overflow").getBoundingClientRect().bottom
          <= scroll.getBoundingClientRect().bottom
      })()
    JS
  end

  it "タスク未登録でも時間枠の高さを維持し、短い枠では登録リンクから案内する" do
    user = FactoryBot.create(:user)
    setting = user.create_schedule_setting!(start_time: "07:00", end_time: "07:40")
    log_in(user)

    expect(page).to have_css(".timeline-frame .timeline-empty", text: "やることを登録しよう")
    frame, = timeline_bounds(".timeline-frame")
    expect(frame["height"]).to eq(120)

    setting.update!(end_time: "07:01")
    visit dashboard_path
    expect(page).to have_css(".timeline-frame .timeline-empty", text: "やることを登録しよう", visible: :hidden)
    frame, = timeline_bounds(".timeline-frame")
    expect(frame["height"]).to eq(3)
    expect(page).to have_link("タスクを登録する", href: new_task_path)
  end
end
