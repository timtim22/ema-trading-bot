class BotSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bot_setting
  before_action :set_tracked_symbols
  
  def index
    @available_symbols = TrackedSymbol.available_symbols
    @timeframes = BotSetting::TIMEFRAMES
    @new_tracked_symbol = TrackedSymbol.new
  end
  
  def update
    respond_to do |format|
      if @bot_setting.update(bot_setting_params)
        format.html { redirect_to dashboard_path, notice: 'Bot settings updated successfully!' }
        format.json { 
          render json: { 
            success: true, 
            message: 'Bot settings updated successfully!',
            settings: {
              symbols: current_user.configured_symbols.join(', '),
              timeframe: @bot_setting.timeframe_display,
              profit_percentage: @bot_setting.profit_percentage,
              loss_percentage: @bot_setting.loss_percentage,
              confirmation_bars: @bot_setting.confirmation_bars
            }
          }
        }
      else
        format.html { render :index, status: :unprocessable_entity }
        format.json { 
          render json: { 
            success: false, 
            message: 'Failed to update settings',
            errors: @bot_setting.errors.full_messages 
          }, status: :unprocessable_entity 
        }
      end
    end
  end
  
  private
  
  def set_bot_setting
    @bot_setting = BotSetting.for_user(current_user)
  end
  
  def set_tracked_symbols
    @tracked_symbols = current_user.all_tracked_symbols
    @active_symbols = current_user.active_tracked_symbols
    @available_to_add = TrackedSymbol.available_symbols - @tracked_symbols.pluck(:symbol)
  end
  
  def bot_setting_params
    params.require(:bot_setting).permit(:timeframe, :profit_percentage, :loss_percentage, :confirmation_bars)
  end
end 