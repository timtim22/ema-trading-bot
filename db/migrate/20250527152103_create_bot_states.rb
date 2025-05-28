class CreateBotStates < ActiveRecord::Migration[8.0]
  def change
    create_table :bot_states do |t|
      t.boolean :running, default: false, null: false
      t.datetime :last_run_at
      t.text :error_message
      t.string :symbol, null: false

      t.timestamps
    end
    
    add_index :bot_states, :symbol, unique: true
    add_index :bot_states, :running
  end
end
