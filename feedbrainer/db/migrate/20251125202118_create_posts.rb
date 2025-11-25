class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :source, null: false, foreign_key: true
      t.jsonb :post

      t.timestamps
    end
  end
end
