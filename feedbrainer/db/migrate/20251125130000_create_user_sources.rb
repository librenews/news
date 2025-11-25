class CreateUserSources < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sources do |t|
      t.references :user, null: false, foreign_key: true
      t.references :source, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_sources, [:user_id, :source_id], unique: true
  end
end

