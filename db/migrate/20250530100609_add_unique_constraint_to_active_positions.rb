class AddUniqueConstraintToActivePositions < ActiveRecord::Migration[8.0]
  def change
    # Add a unique index to prevent duplicate active positions for the same user/symbol
    # This only applies to positions with status 'open' or 'pending'
    # Uses a partial index to only enforce uniqueness for active positions
    add_index :positions, [:user_id, :symbol, :status], 
              unique: true, 
              where: "status IN ('open', 'pending')",
              name: 'index_positions_on_user_symbol_active_status'
  end
end
