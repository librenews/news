class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.text :title, null: false
      t.text :url, null: false
      t.text :summary
      t.datetime :published_at
      t.text :author
      t.text :description
      t.text :image_url
      t.text :html_content
      t.text :body_text
      t.jsonb :entities
      t.jsonb :jsonld_data
      t.jsonb :og_metadata

      t.timestamps
    end
    add_index :articles, :url, unique: true
  end
end
