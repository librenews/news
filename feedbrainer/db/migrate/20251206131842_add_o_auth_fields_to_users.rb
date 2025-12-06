class AddOAuthFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email, :string
    add_column :users, :bluesky_handle, :string
    add_column :users, :bluesky_display_name, :string
    add_column :users, :bluesky_avatar_url, :string
    add_column :users, :bluesky_connected_at, :datetime

    # Add indexes for performance and uniqueness
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
    # Only add atproto_did index if it doesn't exist
    add_index :users, :atproto_did, unique: true, where: "atproto_did IS NOT NULL" unless index_exists?(:users, :atproto_did)
    add_index :users, :bluesky_handle
  end
end
