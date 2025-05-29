class CreateTrackedSymbols < ActiveRecord::Migration[8.0]
  def change
    create_table :tracked_symbols do |t|
      t.references :user, null: false, foreign_key: true
      t.string :symbol, null: false, limit: 10
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    # Add indexes for performance
    add_index :tracked_symbols, [:user_id, :symbol], unique: true
    add_index :tracked_symbols, [:user_id, :active]
    add_index :tracked_symbols, :symbol
  end
end
