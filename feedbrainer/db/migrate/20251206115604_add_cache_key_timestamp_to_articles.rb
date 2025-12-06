class AddCacheKeyTimestampToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :cache_key_timestamp, :datetime
  end
end
