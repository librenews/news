class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :name, null: false
      t.string :type, null: false  # PERSON, ORG, PLACE, EVENT
      t.string :normalized_name, null: false
      t.string :external_reference  # Optional: Wikidata QID, etc.

      t.timestamps
    end
    
    add_index :entities, :normalized_name
    add_index :entities, [:normalized_name, :type], unique: true
  end
end
