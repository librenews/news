class RenameEntityTypeToEntityType < ActiveRecord::Migration[8.0]
  def change
    rename_column :entities, :type, :entity_type
  end
end
