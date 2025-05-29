class RemoveSymbolsFromBotSettings < ActiveRecord::Migration[8.0]
  def change
    remove_column :bot_settings, :symbols, :text
  end
end
