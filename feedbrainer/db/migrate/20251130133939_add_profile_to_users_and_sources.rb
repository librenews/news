class AddProfileToUsersAndSources < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :profile, :jsonb, default: {}
    add_column :sources, :profile, :jsonb, default: {}
    
    add_index :users, :profile, using: :gin
    add_index :sources, :profile, using: :gin
  end
end
