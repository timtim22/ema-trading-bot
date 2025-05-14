class CreatePositions < ActiveRecord::Migration[8.0]
  def change
    create_table :positions do |t|
      t.string :symbol, null: false
      t.decimal :amount, precision: 16, scale: 2, null: false
      t.decimal :entry_price, precision: 16, scale: 8, null: false
      t.string :status, null: false, default: 'open'
      t.decimal :exit_price, precision: 16, scale: 8
      t.string :exit_reason
      t.datetime :entry_time
      t.datetime :exit_time
      t.decimal :profit_loss, precision: 16, scale: 2
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :positions, :symbol
    add_index :positions, :status
    add_index :positions, :entry_time
    add_index :positions, :exit_time
  end
end
