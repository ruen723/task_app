class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, limit: 30, null: false, collation: "utf8mb4_0900_bin"
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :username, unique: true
  end
end
