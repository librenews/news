class AddRelationshipTypeToUserSources < ActiveRecord::Migration[8.0]
  def change
    add_column :user_sources, :relationship_type, :integer, default: 1, null: false
    add_index :user_sources, :relationship_type
  end
end
