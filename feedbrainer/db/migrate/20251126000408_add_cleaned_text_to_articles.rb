class AddCleanedTextToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :cleaned_text, :text
  end
end
