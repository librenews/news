class CreateIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :scope
      t.jsonb :raw_info

      t.timestamps
    end

    # Composite unique index for provider + uid (one user can have multiple providers)
    add_index :identities, [:provider, :uid], unique: true
    # Note: user_id index is already created by t.references above
  end
end
