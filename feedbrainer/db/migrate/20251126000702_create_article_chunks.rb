class CreateArticleChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :article_chunks do |t|
      t.references :article, null: false, foreign_key: true
      t.integer :chunk_index, null: false
      t.text :text, null: false
      t.string :embedding_version
      t.integer :token_count
      t.string :checksum

      t.timestamps
    end
    
    # Add vector column using raw SQL (pgvector extension)
    execute <<-SQL
      ALTER TABLE article_chunks 
      ADD COLUMN embedding_vector vector(384);
    SQL
    
    add_index :article_chunks, [:article_id, :chunk_index], unique: true
    # Add vector index for similarity search (using ivfflat)
    execute <<-SQL
      CREATE INDEX index_article_chunks_on_embedding_vector 
      ON article_chunks 
      USING ivfflat (embedding_vector vector_cosine_ops);
    SQL
  end
end
