class CreateArticlePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :article_posts do |t|
      t.references :article, null: false, foreign_key: true
      t.references :post, null: false, foreign_key: true

      t.timestamps
    end
    add_index :article_posts, [:article_id, :post_id], unique: true
  end
end
