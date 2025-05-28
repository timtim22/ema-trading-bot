class AddTradingLevelsToPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :positions, :take_profit, :decimal, precision: 16, scale: 8
    add_column :positions, :stop_loss, :decimal, precision: 16, scale: 8
    add_column :positions, :current_price, :decimal, precision: 16, scale: 8
    
    add_index :positions, :take_profit
    add_index :positions, :stop_loss
  end
end
