class CreateArticleEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :article_entities do |t|
      t.references :article, null: false, foreign_key: true
      t.references :entity, null: false, foreign_key: true
      t.integer :frequency, default: 1
      t.integer :sentence_positions, array: true, default: []
      t.float :confidence_score

      t.timestamps
    end
    
    add_index :article_entities, [:article_id, :entity_id], unique: true
  end
end

