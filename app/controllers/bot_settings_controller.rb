class BotSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bot_setting
  
  def index
    @available_symbols = BotSetting::AVAILABLE_SYMBOLS
    @timeframes = BotSetting::TIMEFRAMES
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
              symbols: @bot_setting.symbols_display,
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
  
  def bot_setting_params
    params.require(:bot_setting).permit(:timeframe, :profit_percentage, :loss_percentage, :confirmation_bars, symbols: [])
  end
end 