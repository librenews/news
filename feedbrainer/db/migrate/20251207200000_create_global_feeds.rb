class CreateGlobalFeeds < ActiveRecord::Migration[8.0]
  def change
    create_table :global_feeds do |t|
      t.timestamps
    end
  end
end
