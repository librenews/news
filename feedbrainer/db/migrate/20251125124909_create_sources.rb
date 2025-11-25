class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.text :atproto_did

      t.timestamps
    end
  end
end
