class RemoveSolidQueueTables < ActiveRecord::Migration[8.0]
  def change
    # Remove all Solid Queue tables since we're using Sidekiq now
    drop_table :solid_queue_blocked_executions, if_exists: true
    drop_table :solid_queue_claimed_executions, if_exists: true
    drop_table :solid_queue_failed_executions, if_exists: true
    drop_table :solid_queue_ready_executions, if_exists: true
    drop_table :solid_queue_scheduled_executions, if_exists: true
    drop_table :solid_queue_semaphores, if_exists: true
    drop_table :solid_queue_jobs, if_exists: true
    drop_table :solid_queue_processes, if_exists: true
    drop_table :solid_queue_pauses, if_exists: true
  end
end
