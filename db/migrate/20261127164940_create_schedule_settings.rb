class CreateScheduleSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.time :start_time, null: false
      t.time :end_time, null: false

      t.timestamps
    end
  end
end
