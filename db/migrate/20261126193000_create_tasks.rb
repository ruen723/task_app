class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :name, limit: 50, null: false
      t.integer :planned_duration, null: false
      t.integer :position, null: false

      t.timestamps
      t.index %i[user_id position], unique: true
    end
  end
end
