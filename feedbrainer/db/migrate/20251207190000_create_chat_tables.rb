class CreateChatTables < ActiveRecord::Migration[8.0]
  def change
    create_table :chats do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.timestamps
    end

    create_table :chat_contexts do |t|
      t.references :chat, null: false, foreign_key: true
      t.references :context, polymorphic: true, null: false
      t.timestamps
    end

    create_table :chat_messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role, null: false # 'user' or 'assistant'
      t.text :content, null: false
      t.jsonb :context_snapshot # For caching/history
      t.timestamps
    end
  end
end
