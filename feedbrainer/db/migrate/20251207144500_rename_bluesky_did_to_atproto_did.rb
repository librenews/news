class RenameBlueskyDidToAtprotoDid < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :bluesky_did, :atproto_did
  end
end
