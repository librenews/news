class AddUriAndPublishedAtToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :uri, :text
    add_index :posts, :uri
    add_column :posts, :published_at, :datetime
  end
end
