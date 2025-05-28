class CreateTradingSignals < ActiveRecord::Migration[8.0]
  def change
    create_table :trading_signals do |t|
      t.string :symbol, null: false, limit: 10
      t.string :signal_type, null: false, limit: 20
      t.decimal :price, precision: 16, scale: 8, null: false
      t.decimal :ema5, precision: 16, scale: 8, null: false
      t.decimal :ema8, precision: 16, scale: 8, null: false
      t.decimal :ema22, precision: 16, scale: 8, null: false
      t.datetime :timestamp, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    # Add indexes for performance
    add_index :trading_signals, [:user_id, :symbol, :timestamp]
    add_index :trading_signals, [:symbol, :timestamp]
    add_index :trading_signals, :timestamp
  end
end
