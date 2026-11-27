require "rails_helper"

RSpec.describe ScheduleSetting do
  let(:user) { FactoryBot.create(:user) }
  let(:setting) { user.build_schedule_setting(start_time: "07:05", end_time: "08:10") }

  describe "#available_minutes" do
    it "最小時間枠を1分として計算する" do
      setting.assign_attributes(start_time: "07:59", end_time: "08:00")

      expect(setting.available_minutes).to eq(1)
    end

    it "最大時間枠を1439分として計算する" do
      setting.assign_attributes(start_time: "00:00", end_time: "23:59")

      expect(setting.available_minutes).to eq(1439)
    end
  end

  describe "#time_breakdown" do
    {
      "余裕がある" => [ 45, 15, 0 ],
      "完全に一致する" => [ 60, 0, 0 ],
      "超過する" => [ 75, 0, 15 ],
      "1分だけ余る" => [ 59, 1, 0 ],
      "1分だけ超過する" => [ 61, 0, 1 ],
      "タスクがない" => [ 0, 60, 0 ]
    }.each do |description, (total_planned_minutes, free_minutes, overflow_minutes)|
      it "#{description}場合に利用可能時間・自由時間・超過時間を分で返す" do
        setting.assign_attributes(start_time: "07:00", end_time: "08:00")

        expect(setting.time_breakdown(total_planned_minutes)).to eq(
          available_minutes: 60, free_minutes: free_minutes, overflow_minutes: overflow_minutes
        )
      end
    end
  end

  it "分単位の時刻を保存・再取得・再検証し、片方の時刻も更新できる" do
    setting.save!
    setting.reload
    expect(setting).to be_valid
    expect(setting.start_time.strftime("%H:%M:%S")).to eq("07:05:00")
    expect(setting.end_time.strftime("%H:%M:%S")).to eq("08:10:00")

    setting.update!(end_time: "23:59")
    setting.reload
    expect(setting.start_time.strftime("%H:%M")).to eq("07:05")
    expect(setting.end_time.strftime("%H:%M")).to eq("23:59")
  end

  it "同じ日の最初と最後の分を受け付ける" do
    setting.assign_attributes(start_time: "00:00", end_time: "23:59")
    expect(setting).to be_valid
  end

  it "両方の時刻を必須とする" do
    setting.assign_attributes(start_time: "", end_time: nil)
    expect(setting).not_to be_valid
    expect(setting.errors.of_kind?(:start_time, :blank)).to be true
    expect(setting.errors.of_kind?(:end_time, :blank)).to be true
  end

  %w[24:00 07:60 abc 07:05abc 07:05:00 07:05:01 2026-11-27T07:05].each do |input|
    it "#{input} を時計時刻として受け付けない" do
      setting.start_time = input
      expect(setting).not_to be_valid
      expect(setting.errors.of_kind?(:start_time, :invalid_clock_time)).to be true
    end
  end

  it "同時刻、逆順、日付またぎを拒否する" do
    [ [ "07:00", "07:00" ], [ "08:00", "07:00" ], [ "23:00", "01:00" ] ].each do |start_time, end_time|
      setting.assign_attributes(start_time: start_time, end_time: end_time)
      expect(setting).not_to be_valid
      expect(setting.errors.of_kind?(:end_time, :after_start_time)).to be true
    end
  end

  it "同じユーザーの重複をモデルとDBの両方で拒否する" do
    setting.save!
    duplicate = ScheduleSetting.new(user: user, start_time: "07:00", end_time: "08:00")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors.of_kind?(:user_id, :taken)).to be true

    expect do
      ScheduleSetting.insert_all!([ { user_id: user.id, start_time: "07:00", end_time: "08:00" } ])
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
