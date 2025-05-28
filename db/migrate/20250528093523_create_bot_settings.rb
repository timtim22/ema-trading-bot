class CreateBotSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :bot_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.text :symbols, default: '["AAPL"]'
      t.string :timeframe, default: '5m'
      t.decimal :profit_percentage, precision: 5, scale: 2, default: 2.0
      t.decimal :loss_percentage, precision: 5, scale: 2, default: 1.0
      t.integer :confirmation_bars, default: 3

      t.timestamps
    end
    
    # Only add index if it doesn't exist
    unless index_exists?(:bot_settings, :user_id)
      add_index :bot_settings, :user_id, unique: true
    end
  end
end
