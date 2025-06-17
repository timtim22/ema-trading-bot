class CreateUnfilledOrderAlerts < ActiveRecord::Migration[8.0]
  def change
    create_table :unfilled_order_alerts do |t|
      t.references :position, null: false, foreign_key: true
      t.string :order_id
      t.integer :timeout_duration

      t.timestamps
    end
  end
end
