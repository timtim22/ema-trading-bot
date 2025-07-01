class CreateSolidQueueTables < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.timestamps
    end

    add_index :solid_queue_jobs, [:queue_name, :finished_at, :priority, :created_at], name: "index_solid_queue_jobs_for_execution"
    add_index :solid_queue_jobs, [:active_job_id]
    add_index :solid_queue_jobs, [:concurrency_key, :priority, :created_at]

    create_table :solid_queue_scheduled_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.string :queue_name, null: false
      t.integer :priority, default: 0
      t.datetime :scheduled_at, null: false
      t.timestamps
    end

    add_index :solid_queue_scheduled_executions, [:scheduled_at, :priority, :created_at], name: "index_solid_queue_scheduled_executions_for_execution"

    create_table :solid_queue_ready_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.string :queue_name, null: false
      t.integer :priority, default: 0
      t.timestamps
    end

    add_index :solid_queue_ready_executions, [:priority, :created_at], name: "index_solid_queue_ready_executions_for_execution"

    create_table :solid_queue_claimed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.string :process_id
      t.timestamps
    end

    add_index :solid_queue_claimed_executions, [:process_id, :created_at]

    create_table :solid_queue_blocked_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.string :queue_name, null: false
      t.integer :priority, default: 0
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :solid_queue_blocked_executions, [:expires_at, :concurrency_key]

    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs }
      t.text :error
      t.datetime :failed_at, null: false
      t.timestamps
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.timestamps
    end

    add_index :solid_queue_pauses, [:queue_name], unique: true

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.text :supervisor_pid
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.timestamps
    end

    add_index :solid_queue_processes, [:last_heartbeat_at], name: "index_solid_queue_processes_on_last_heartbeat_at"
    add_index :solid_queue_processes, [:kind, :last_heartbeat_at], name: "index_solid_queue_processes_on_kind_and_last_heartbeat_at"

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1
      t.datetime :expires_at
      t.timestamps
    end

    add_index :solid_queue_semaphores, [:key, :value], name: "index_solid_queue_semaphores_on_key_and_value"
    add_index :solid_queue_semaphores, [:key], unique: true
  end
end
