class CreateActivityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :activity_logs do |t|
      t.string :event_type, null: false
      t.string :level, null: false
      t.text :message, null: false
      t.string :symbol
      t.references :user, null: true, foreign_key: true
      t.json :details, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end
    
    # Add indexes for efficient filtering
    add_index :activity_logs, :event_type
    add_index :activity_logs, :level
    add_index :activity_logs, :symbol
    add_index :activity_logs, :occurred_at
    add_index :activity_logs, [:user_id, :occurred_at]
    add_index :activity_logs, [:event_type, :level]
    add_index :activity_logs, [:event_type, :occurred_at]
  end
end
