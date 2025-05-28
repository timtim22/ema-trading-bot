class AddOrderDetailsToPositions < ActiveRecord::Migration[8.0]
  def change
    add_column :positions, :primary_order_id, :string
    add_column :positions, :take_profit_order_id, :string
    add_column :positions, :stop_loss_order_id, :string
    add_column :positions, :fill_qty, :decimal, precision: 16, scale: 8
    add_column :positions, :fill_notional, :decimal, precision: 16, scale: 2
    
    add_index :positions, :primary_order_id
  end
end
