class PopulateTrackedSymbolsForExistingUsers < ActiveRecord::Migration[8.0]
  def up
    # For each existing user, create TrackedSymbol records based on their bot_setting symbols
    User.includes(:bot_setting, :tracked_symbols).find_each do |user|
      # Skip if user already has tracked symbols
      next if user.tracked_symbols.exists?
      
      # Get symbols from bot_setting or use defaults
      symbols = if user.bot_setting&.symbols_list&.any?
                  user.bot_setting.symbols_list
                else
                  %w[AAPL NVDA MSFT] # Default symbols
                end
      
      # Create TrackedSymbol records for each symbol
      symbols.each do |symbol|
        user.tracked_symbols.create!(
          symbol: symbol.upcase,
          active: true
        )
      end
      
      puts "Created #{symbols.length} tracked symbols for user #{user.email}: #{symbols.join(', ')}"
    end
  end

  def down
    # Remove all tracked symbols (this is destructive, so be careful)
    TrackedSymbol.delete_all
  end
end
