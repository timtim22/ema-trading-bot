class CreateEmaReadings < ActiveRecord::Migration[8.0]
  def change
    create_table :ema_readings do |t|
      t.string :symbol, null: false
      t.integer :period, null: false
      t.decimal :value, precision: 16, scale: 8, null: false
      t.datetime :timestamp, null: false

      t.timestamps
    end
    
    add_index :ema_readings, [:symbol, :period, :timestamp]
    add_index :ema_readings, :timestamp
  end
end
